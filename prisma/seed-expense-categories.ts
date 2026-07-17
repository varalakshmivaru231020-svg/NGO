// One-off: the Expense management feature shipped after the last full seed
// ran against production, so ExpenseCategory was empty there, leaving the
// "Add Expense" screen's category picker with nothing to show. Additive
// only (upsert by unique key) — does not touch donors/students/donations.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  await Promise.all([
    prisma.expenseCategory.upsert({ where: { key: 'salaries' }, update: {}, create: { key: 'salaries', label: 'Salaries', icon: 'wallet' } }),
    prisma.expenseCategory.upsert({ where: { key: 'utilities' }, update: {}, create: { key: 'utilities', label: 'Utilities', icon: 'bolt' } }),
    prisma.expenseCategory.upsert({ where: { key: 'maintenance' }, update: {}, create: { key: 'maintenance', label: 'Maintenance', icon: 'tool' } }),
    prisma.expenseCategory.upsert({ where: { key: 'program' }, update: {}, create: { key: 'program', label: 'Program & Welfare', icon: 'heart' } }),
    prisma.expenseCategory.upsert({ where: { key: 'admin' }, update: {}, create: { key: 'admin', label: 'Administrative', icon: 'briefcase' } }),
    prisma.expenseCategory.upsert({ where: { key: 'transport' }, update: {}, create: { key: 'transport', label: 'Transport', icon: 'truck' } }),
    prisma.expenseCategory.upsert({ where: { key: 'misc' }, update: {}, create: { key: 'misc', label: 'Miscellaneous', icon: 'wallet' } }),
  ]);

  const categories = await prisma.expenseCategory.findMany({ select: { key: true, label: true } });
  console.log('EXPENSE CATEGORIES NOW ' + JSON.stringify(categories));
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
