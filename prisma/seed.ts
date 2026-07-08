import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding Saksham Foundation database...');

  // Offices
  const hq = await prisma.office.upsert({
    where: { id: 'office-hq' },
    update: {},
    create: { id: 'office-hq', name: 'Head Office', city: 'Mumbai', state: 'Maharashtra', address: '12, Nariman Point, Mumbai - 400021', phone: '+91 22 4001 2233', email: 'hq@saksham.org', isHQ: true },
  });
  const pune = await prisma.office.upsert({
    where: { id: 'office-pune' },
    update: {},
    create: { id: 'office-pune', name: 'Pune Branch', city: 'Pune', state: 'Maharashtra', address: 'Baner Road, Pune - 411045', phone: '+91 20 4500 7788' },
  });

  // Single fresh SUPER_ADMIN — every other account (team members, roles) is
  // created dynamically in the app. Override via env for each new deployment
  // (e.g. a new org/tenant) so every fresh instance doesn't ship with the
  // same SKET-branded default login.
  const adminEmail = process.env.SEED_ADMIN_EMAIL || 'admin@sket.org';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD || 'Sket@2026';
  const adminHash = await argon2.hash(adminPassword);
  await prisma.user.upsert({
    where: { email: adminEmail },
    update: { role: 'SUPER_ADMIN', isActive: true, passwordHash: adminHash, name: 'Super Admin' },
    create: { name: 'Super Admin', email: adminEmail, passwordHash: adminHash, role: 'SUPER_ADMIN' },
  });

  // Donor Categories
  const cats = await Promise.all([
    prisma.donorCategory.upsert({ where: { name: 'Corporate' }, update: {}, create: { name: 'Corporate', description: 'Corporate donors & CSR', icon: 'building', color: '#0E8C76', sortOrder: 1 } }),
    prisma.donorCategory.upsert({ where: { name: 'Individual' }, update: {}, create: { name: 'Individual', description: 'Individual philanthropists', icon: 'user', color: '#2D9CDB', sortOrder: 2 } }),
    prisma.donorCategory.upsert({ where: { name: 'Recurring' }, update: {}, create: { name: 'Recurring', description: 'Monthly/quarterly givers', icon: 'refresh', color: '#7C6CF0', sortOrder: 3 } }),
    prisma.donorCategory.upsert({ where: { name: 'Education Sponsor' }, update: {}, create: { name: 'Education Sponsor', description: 'Child sponsorship donors', icon: 'grad', color: '#F6A723', sortOrder: 4 } }),
    prisma.donorCategory.upsert({ where: { name: 'Health' }, update: {}, create: { name: 'Health', description: 'Healthcare funding', icon: 'heart', color: '#EC5B8B', sortOrder: 5 } }),
  ]);

  // Donation Types
  const types = await Promise.all([
    prisma.donationType.upsert({ where: { key: 'general' }, update: {}, create: { key: 'general', label: 'General Donation', icon: 'gift' } }),
    prisma.donationType.upsert({ where: { key: 'education' }, update: {}, create: { key: 'education', label: 'Education Fund', icon: 'grad' } }),
    prisma.donationType.upsert({ where: { key: 'health' }, update: {}, create: { key: 'health', label: 'Healthcare', icon: 'heart' } }),
    prisma.donationType.upsert({ where: { key: 'food' }, update: {}, create: { key: 'food', label: 'Food & Nutrition', icon: 'gift' } }),
    prisma.donationType.upsert({ where: { key: 'sponsorship' }, update: {}, create: { key: 'sponsorship', label: 'Child Sponsorship', icon: 'users' } }),
  ]);

  // Centers
  const centerA = await prisma.center.upsert({
    where: { name: 'Dharavi Centre' },
    update: {},
    create: { name: 'Dharavi Centre', city: 'Mumbai', address: 'Sector 5, Dharavi, Mumbai' },
  });
  const centerB = await prisma.center.upsert({
    where: { name: 'Hadapsar Centre' },
    update: {},
    create: { name: 'Hadapsar Centre', city: 'Pune', address: 'Magarpatta Road, Hadapsar, Pune' },
  });

  // Donors
  const donorData = [
    { donorCode: 'DID00001', name: 'Rajesh Khanna', mobile: '+91 98201 44521', email: 'rajesh.khanna@gmail.com', city: 'Mumbai', state: 'Maharashtra', tier: 'PLATINUM', gender: 'MALE', dob: new Date('1972-08-12'), occupation: 'Business Owner', company: 'Khanna Textiles Pvt Ltd', catIdx: [0, 2] },
    { donorCode: 'DID00002', name: 'Priya Sharma', mobile: '+91 99303 22118', email: 'priya.sharma@outlook.com', city: 'Pune', state: 'Maharashtra', tier: 'GOLD', gender: 'FEMALE', dob: new Date('1985-06-04'), occupation: 'Architect', catIdx: [1, 3] },
    { donorCode: 'DID00003', name: 'Arjun Mehta', mobile: '+91 90040 88876', email: 'arjun.mehta@techcorp.in', city: 'Bengaluru', state: 'Karnataka', tier: 'GOLD', gender: 'MALE', dob: new Date('1990-03-19'), occupation: 'Engineering Manager', catIdx: [0, 2] },
    { donorCode: 'DID00004', name: 'Sunita Iyer', mobile: '+91 97650 33212', email: 'sunita.iyer@gmail.com', city: 'Chennai', state: 'Tamil Nadu', tier: 'SILVER', gender: 'FEMALE', dob: new Date('1978-11-30'), occupation: 'Teacher', catIdx: [1] },
    { donorCode: 'DID00005', name: 'Vivek Gupta', mobile: '+91 88001 55432', email: 'vivek.gupta@gmail.com', city: 'Delhi', state: 'Delhi', tier: 'SILVER', gender: 'MALE', dob: new Date('1982-07-22'), occupation: 'Doctor', catIdx: [1, 4] },
    { donorCode: 'DID00006', name: 'Ananya Patel', mobile: '+91 91234 67890', email: 'ananya.patel@corp.com', city: 'Ahmedabad', state: 'Gujarat', tier: 'GOLD', gender: 'FEMALE', dob: new Date('1988-04-15'), company: 'Patel Industries', catIdx: [0, 3] },
    { donorCode: 'DID00007', name: 'Kiran Reddy', mobile: '+91 93456 12345', email: 'kiran.reddy@tech.in', city: 'Hyderabad', state: 'Telangana', tier: 'SILVER', gender: 'MALE', dob: new Date('1995-09-08'), occupation: 'Software Engineer', catIdx: [1] },
    { donorCode: 'DID00008', name: 'Meera Nambiar', mobile: '+91 94567 23456', email: 'meera@gmail.com', city: 'Kochi', state: 'Kerala', tier: 'PLATINUM', gender: 'FEMALE', dob: new Date('1965-02-28'), occupation: 'Retired Banker', catIdx: [1, 2, 4] },
  ];

  const donors: any[] = [];
  for (const d of donorData) {
    const { catIdx, ...data } = d;
    const donor = await prisma.donor.upsert({
      where: { donorCode: data.donorCode },
      update: {},
      create: {
        ...data,
        categories: { create: catIdx.map((i: number) => ({ categoryId: cats[i].id })) },
      },
    });
    donors.push(donor);
  }

  // Students
  const studentData = [
    { name: 'Aarav Singh', gender: 'MALE', dob: new Date('2012-04-10'), centerId: centerA.id, class: '6th', school: 'Municipal School No.3', status: 'ACTIVE', fatherName: 'Ravi Singh', guardianPhone: '+91 9876500001' },
    { name: 'Diya Patil', gender: 'FEMALE', dob: new Date('2013-08-22'), centerId: centerA.id, class: '5th', school: 'Municipal School No.3', status: 'ACTIVE', motherName: 'Sunita Patil', guardianPhone: '+91 9876500002' },
    { name: 'Rohan Kamble', gender: 'MALE', dob: new Date('2011-01-15'), centerId: centerA.id, class: '7th', school: 'Govt High School', status: 'ACTIVE', fatherName: 'Suresh Kamble', guardianPhone: '+91 9876500003' },
    { name: 'Kavya Desai', gender: 'FEMALE', dob: new Date('2010-11-05'), centerId: centerB.id, class: '8th', school: 'ZP School Hadapsar', status: 'ACTIVE', motherName: 'Rekha Desai', guardianPhone: '+91 9876500004' },
    { name: 'Aryan Chavan', gender: 'MALE', dob: new Date('2014-03-18'), centerId: centerB.id, class: '4th', school: 'ZP School Hadapsar', status: 'ACTIVE', fatherName: 'Raju Chavan', guardianPhone: '+91 9876500005' },
    { name: 'Sneha More', gender: 'FEMALE', dob: new Date('2009-07-30'), centerId: centerA.id, class: '9th', school: 'Govt High School', status: 'GRADUATED', motherName: 'Lata More', guardianPhone: '+91 9876500006' },
  ];

  const students: any[] = [];
  const centerACount: Record<string, number> = {};
  for (const s of studentData) {
    const prefix = s.centerId === centerA.id ? 'DHR' : 'HDP';
    centerACount[prefix] = (centerACount[prefix] || 0) + 1;
    const childId = `${prefix}${String(centerACount[prefix]).padStart(4, '0')}`;
    const student = await prisma.student.upsert({
      where: { childId },
      update: {},
      create: { ...s, childId },
    });
    students.push(student);
  }

  // Donations
  const donationRecords = [
    { donorIdx: 0, typeIdx: 0, amount: 500000, mode: 'BANK_TRANSFER', date: new Date('2026-05-28') },
    { donorIdx: 0, typeIdx: 1, amount: 200000, mode: 'CHEQUE', date: new Date('2026-04-10') },
    { donorIdx: 1, typeIdx: 4, amount: 150000, mode: 'UPI', date: new Date('2026-06-01') },
    { donorIdx: 2, typeIdx: 0, amount: 100000, mode: 'BANK_TRANSFER', date: new Date('2026-05-15') },
    { donorIdx: 3, typeIdx: 2, amount: 25000, mode: 'CASH', date: new Date('2026-05-20') },
    { donorIdx: 4, typeIdx: 2, amount: 50000, mode: 'UPI', date: new Date('2026-06-05') },
    { donorIdx: 5, typeIdx: 3, amount: 75000, mode: 'BANK_TRANSFER', date: new Date('2026-06-08') },
    { donorIdx: 6, typeIdx: 0, amount: 20000, mode: 'UPI', date: new Date('2026-06-10') },
    { donorIdx: 7, typeIdx: 1, amount: 300000, mode: 'CHEQUE', date: new Date('2026-06-12') },
    { donorIdx: 0, typeIdx: 0, amount: 100000, mode: 'BANK_TRANSFER', date: new Date('2026-06-14') },
  ];

  for (let i = 0; i < donationRecords.length; i++) {
    const r = donationRecords[i];
    const year = r.date.getFullYear();
    const receiptNo = `RCP/${year}/${String(i + 1).padStart(6, '0')}`;
    await prisma.donation.upsert({
      where: { receiptNo },
      update: {},
      create: {
        receiptNo,
        donorId: donors[r.donorIdx].id,
        typeId: types[r.typeIdx].id,
        amount: r.amount,
        paymentMode: r.mode,
        status: 'COMPLETED',
        date: r.date,
        taxExemption: r.amount >= 50000,
      },
    });
  }

  // Sponsorships
  await prisma.sponsorship.upsert({ where: { id: 'spon-1' }, update: {}, create: { id: 'spon-1', studentId: students[0].id, donorId: donors[1].id, amount: 48000, frequency: 'ANNUAL' } });
  await prisma.sponsorship.upsert({ where: { id: 'spon-2' }, update: {}, create: { id: 'spon-2', studentId: students[1].id, donorId: donors[1].id, amount: 48000, frequency: 'ANNUAL' } });
  await prisma.sponsorship.upsert({ where: { id: 'spon-3' }, update: {}, create: { id: 'spon-3', studentId: students[3].id, donorId: donors[5].id, amount: 60000, frequency: 'ANNUAL' } });

  // Achievements
  const achData = [
    { studentId: students[0].id, title: '1st Place — District Math Olympiad', category: 'ACADEMICS', date: new Date('2026-04-15'), description: 'Won first place among 240 participants across 12 schools.' },
    { studentId: students[2].id, title: 'State-Level Cricket — Under-14', category: 'SPORTS', date: new Date('2026-03-10'), description: 'Selected for state under-14 cricket tournament.' },
    { studentId: students[3].id, title: 'Annual Cultural Festival Winner', category: 'CULTURAL', date: new Date('2026-02-20'), description: 'Won best performer award at inter-school cultural festival.' },
  ];
  for (const a of achData) {
    await prisma.achievement.create({ data: a }).catch(() => {});
  }

  // Reminders
  const remData = [
    { donorId: donors[0].id, type: 'BIRTHDAY', title: `Birthday: ${donors[0].name}`, dueDate: new Date('2026-08-12') },
    { donorId: donors[1].id, type: 'FOLLOW_UP', title: `Follow-up: ${donors[1].name}`, message: 'Check sponsorship renewal status.', dueDate: new Date('2026-06-20') },
    { type: 'CUSTOM', title: 'Quarterly Report Prep', message: 'Prepare Q2 donor report for board meeting.', dueDate: new Date('2026-06-30') },
  ] as const;
  for (const r of remData) {
    await prisma.reminder.create({ data: r as any }).catch(() => {});
  }

  console.log('Seed complete!');
  console.log(`Login: ${adminEmail} / ${adminPassword}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
