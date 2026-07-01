// One-off: clear all operational/test data so the app can be tested from a
// clean slate. KEEPS: Super Admin logins, donation types & donor categories
// (reference data needed to create donations/donors).
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Children of donors/students first (FK order).
  await prisma.attendance.deleteMany();
  await prisma.achievement.deleteMany();
  await prisma.sponsorship.deleteMany();
  await prisma.donation.deleteMany();
  await prisma.reminder.deleteMany();
  await prisma.paymentLink.deleteMany();
  await prisma.donorCategoryMap.deleteMany();
  await prisma.student.deleteMany();
  await prisma.donor.deleteMany();
  await prisma.center.deleteMany();

  // Approval history + notifications.
  await prisma.approvalRequest.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.deviceToken.deleteMany();

  // Team members (everyone except Super Admins). Cascades their tokens.
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany({ where: { role: { not: 'SUPER_ADMIN' } } });

  // Detach Super Admins from offices, then remove all offices.
  await prisma.user.updateMany({ data: { officeId: null } });
  await prisma.office.deleteMany();

  const counts = {
    users: await prisma.user.count(),
    students: await prisma.student.count(),
    donors: await prisma.donor.count(),
    donations: await prisma.donation.count(),
    offices: await prisma.office.count(),
    centers: await prisma.center.count(),
    approvals: await prisma.approvalRequest.count(),
    donationTypes: await prisma.donationType.count(),
    donorCategories: await prisma.donorCategory.count(),
  };
  const kept = await prisma.user.findMany({ select: { email: true, role: true } });
  console.log('WIPE DONE ' + JSON.stringify(counts));
  console.log('KEPT USERS ' + JSON.stringify(kept));
}

main()
  .catch((e) => { console.error('WIPE ERROR', e); process.exit(1); })
  .finally(() => prisma.$disconnect());
