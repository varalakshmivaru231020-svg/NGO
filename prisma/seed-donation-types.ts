// One-off: this deployment's database only ever got the two donation types
// PublicDonationsService.onModuleInit() auto-provisions ("Skill Development",
// "Women Empowerment") — the full seed.ts (which also creates demo
// donors/students/donations) was never run here. Additive only (upsert by
// unique key) — does not touch donors/students/donations.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  await Promise.all([
    prisma.donationType.upsert({ where: { key: 'general' }, update: {}, create: { key: 'general', label: 'General Donation', icon: 'gift' } }),
    prisma.donationType.upsert({ where: { key: 'education' }, update: {}, create: { key: 'education', label: 'Education Fund', icon: 'grad' } }),
    prisma.donationType.upsert({ where: { key: 'health' }, update: {}, create: { key: 'health', label: 'Healthcare', icon: 'heart' } }),
    prisma.donationType.upsert({ where: { key: 'food' }, update: {}, create: { key: 'food', label: 'Food & Nutrition', icon: 'gift' } }),
    prisma.donationType.upsert({ where: { key: 'sponsorship' }, update: {}, create: { key: 'sponsorship', label: 'Child Sponsorship', icon: 'users' } }),
  ]);

  const types = await prisma.donationType.findMany({ select: { key: true, label: true } });
  console.log('DONATION TYPES NOW ' + JSON.stringify(types));
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
