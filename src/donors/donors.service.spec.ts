import { ConflictException } from '@nestjs/common';
import { DonorsService } from './donors.service';

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
