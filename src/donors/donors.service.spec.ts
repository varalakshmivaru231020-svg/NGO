import { ConflictException } from '@nestjs/common';
import { DonorsService, parseSheetDate } from './donors.service';

// name + mobile together identify a donor. These cover the pair rule itself —
// what counts as the same donor, and what must still be allowed through.
describe('DonorsService duplicate guard', () => {
  const existing = [
    { id: 'd1', name: 'Kishore V', mobile: '9986064411', donorCode: 'DID00001' },
    { id: 'd2', name: 'Mohan Raj', mobile: '9620794141', donorCode: 'DID00002' },
  ];

  let created: any[];
  let svc: DonorsService;

  beforeEach(() => {
    created = [];
    const prisma: any = {
      donor: {
        // Mirrors the real query: exact match on EITHER field, MySQL-style
        // case-insensitive equality.
        findMany: jest.fn(async ({ where }: any) => {
          const [byName, byMobile] = where.OR;
          return existing.filter(
            (d) =>
              d.name.toLowerCase() === String(byName.name).toLowerCase() ||
              d.mobile === byMobile.mobile,
          );
        }),
        create: jest.fn(async ({ data }: any) => {
          created.push(data);
          return { id: 'new', ...data };
        }),
      },
      $transaction: jest.fn(async () => 3),
      $executeRaw: jest.fn(),
      $queryRaw: jest.fn(),
    };
    svc = new DonorsService(prisma);
    // nextCode() uses raw SQL against a real sequence table — stub it out.
    (svc as any).nextCode = async () => 'DID00003';
  });

  const create = (name: string, mobile: string) =>
    svc.create({ name, mobile } as any);

  it('rejects the exact same name and mobile', async () => {
    await expect(create('Kishore V', '9986064411')).rejects.toBeInstanceOf(ConflictException);
    expect(created).toHaveLength(0);
  });

  it('names the existing donor and its code in the message', async () => {
    await expect(create('Kishore V', '9986064411')).rejects.toThrow(
      'Kishore V with mobile 9986064411 is already added (DID00001).',
    );
  });

  it('rejects differing case and spacing in the name', async () => {
    await expect(create('  kishore   v ', '9986064411')).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects a mobile written with spaces or punctuation', async () => {
    await expect(create('Kishore V', '99860-64411')).rejects.toBeInstanceOf(ConflictException);
  });

  it('allows the same name with a different number', async () => {
    await expect(create('Kishore V', '9000000001')).resolves.toBeDefined();
    expect(created).toHaveLength(1);
  });

  it('allows the same number with a different name (shared family phone)', async () => {
    await expect(create('Lakshmi V', '9986064411')).resolves.toBeDefined();
    expect(created).toHaveLength(1);
  });

  it('allows a genuinely new donor', async () => {
    await expect(create('Srinivas L', '9111111111')).resolves.toBeDefined();
    expect(created).toHaveLength(1);
  });

  it('lets a donor keep its own name and mobile when edited', async () => {
    await expect(
      (svc as any).assertNotDuplicate('Kishore V', '9986064411', 'd1'),
    ).resolves.toBeUndefined();
  });

  it('blocks an edit that collides with a different donor', async () => {
    await expect(
      (svc as any).assertNotDuplicate('Kishore V', '9986064411', 'd2'),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

// Bulk import: every row is judged on its own, duplicates are skipped rather
// than failed, and the rest of the file still goes in.
describe('DonorsService.importMany', () => {
  const existing = [{ name: 'Kishore V', mobile: '9986064411', donorCode: 'DID00001' }];
  let created: any[];
  let svc: DonorsService;

  beforeEach(() => {
    created = [];
    const prisma: any = {
      donor: {
        findMany: jest.fn(async () => existing),
        create: jest.fn(async ({ data }: any) => {
          created.push(data);
          return { id: `id${created.length}` };
        }),
      },
      donorCategory: { findMany: jest.fn(async () => [{ id: 'c1', name: 'Regular Donor' }]) },
    };
    svc = new DonorsService(prisma);
    (svc as any).nextCodes = async (n: number) =>
      Array.from({ length: n }, (_, i) => `DID${String(10 + i).padStart(5, '0')}`);
  });

  const run = (donors: any[]) => svc.importMany({ donors } as any);

  it('creates valid rows and hands out codes in file order', async () => {
    const res = await run([
      { row: 2, name: 'Asha R', mobile: '9000000001', gender: 'female', tier: 'gold', category: 'regular donor' },
      { row: 3, name: 'Ravi  K', mobile: '+91 90000-00002', dob: '15/08/1980' },
    ]);
    expect(res).toMatchObject({ total: 2, created: 2, skipped: 0, failed: 0 });
    expect(res.results.map((r) => r.donorCode)).toEqual(['DID00010', 'DID00011']);
    expect(created[0]).toMatchObject({
      name: 'Asha R', gender: 'FEMALE', tier: 'GOLD', categories: { create: [{ categoryId: 'c1' }] },
    });
    expect(created[1]).toMatchObject({ name: 'Ravi K', mobile: '+919000000002', gender: 'MALE', tier: 'SILVER' });
    expect(created[1].dob.toISOString()).toBe('1980-08-15T00:00:00.000Z');
  });

  it('skips a row that matches an existing donor by name + mobile', async () => {
    const res = await run([{ row: 2, name: 'kishore  v', mobile: '99860 64411' }]);
    expect(res.skipped).toBe(1);
    expect(res.results[0].reason).toBe('Already added as DID00001');
    expect(created).toHaveLength(0);
  });

  it('skips the second copy of a donor repeated inside the file', async () => {
    const res = await run([
      { row: 2, name: 'Meena S', mobile: '9000000003' },
      { row: 3, name: 'Meena S', mobile: '9000000003' },
    ]);
    expect(res).toMatchObject({ created: 1, skipped: 1 });
    expect(res.results[1].reason).toBe('Same name and mobile as row 2 of this file');
  });

  it('fails a row with bad cells, names each problem, and keeps importing the rest', async () => {
    const res = await run([
      { row: 2, name: '', mobile: '12345', gender: 'unknown', dob: 'yesterday' },
      { row: 3, name: 'Ok Donor', mobile: '9000000004' },
    ]);
    expect(res).toMatchObject({ created: 1, failed: 1 });
    const reason = res.results[0].reason!;
    expect(reason).toContain('Name is missing');
    expect(reason).toContain('10–15 digits');
    expect(reason).toContain('Gender');
    expect(reason).toContain('Date of birth');
    expect(created).toHaveLength(1);
  });

  it('still creates a row whose category is unknown, and notes it', async () => {
    const res = await run([{ row: 2, name: 'Noted', mobile: '9000000005', category: 'VIP' }]);
    expect(res.created).toBe(1);
    expect(res.results[0].note).toBe('Category "VIP" not found — left unassigned');
    expect(created[0].categories).toBeUndefined();
  });

  it('normalises contact preferences to the stored CSV form', async () => {
    await run([{ row: 2, name: 'Pref', mobile: '9000000006', preferredContactMethod: 'WhatsApp, call, whatsapp' }]);
    expect(created[0].preferredContactMethod).toBe('WHATSAPP,CALL');
  });

  it('numbers rows from 2 when the client sends none', async () => {
    const res = await run([{ name: 'A', mobile: '9000000007' }, { name: 'B', mobile: '9000000008' }]);
    expect(res.results.map((r) => r.row)).toEqual([2, 3]);
  });
});

describe('parseSheetDate', () => {
  const iso = (d: Date | null | undefined) => (d instanceof Date ? d.toISOString().slice(0, 10) : d);

  it('reads ISO, day-first and Excel serial dates', () => {
    expect(iso(parseSheetDate('2024-03-15'))).toBe('2024-03-15');
    expect(iso(parseSheetDate('2024-03-15T10:20:30.000Z'))).toBe('2024-03-15');
    expect(iso(parseSheetDate('15/03/2024'))).toBe('2024-03-15');
    expect(iso(parseSheetDate('5-3-24'))).toBe('2024-03-05');
    expect(iso(parseSheetDate('15.03.1999'))).toBe('1999-03-15');
    expect(iso(parseSheetDate(45366))).toBe('2024-03-15');
  });

  it('tells a blank cell apart from an unreadable one', () => {
    expect(parseSheetDate('')).toBeUndefined();
    expect(parseSheetDate(undefined)).toBeUndefined();
    expect(parseSheetDate('31/02/2024')).toBeNull();
    expect(parseSheetDate('March 15')).toBeNull();
  });
});
