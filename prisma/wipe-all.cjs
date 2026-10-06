// Full test-data wipe for go-live. KEEPS: Super Admin logins, donation types,
// org/WhatsApp/Razorpay settings. Resets receipt/donor-code numbering to 1.
// A full JSON backup should exist first (~/backups/pre-wipe-backup.json).
// Run on the server:  node prisma/wipe-all.cjs
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

(async () => {
  // Children first (FK order)
  await p.attendance.deleteMany();
  await p.growthRecord.deleteMany();
  await p.progressRecord.deleteMany();
  await p.studentDocument.deleteMany();
  await p.achievement.deleteMany();
  await p.sponsorship.deleteMany();
  await p.donation.deleteMany();
  await p.expense.deleteMany();
  await p.expenseCategory.deleteMany();
  await p.reminder.deleteMany();
  await p.paymentLink.deleteMany();
  await p.donorCategoryMap.deleteMany();
  await p.student.deleteMany();
  await p.donor.deleteMany();
  await p.staff.deleteMany(); // cascades staff_children; must go before centres (FK)
  await p.center.deleteMany();
  await p.approvalRequest.deleteMany();
  await p.notification.deleteMany();
  await p.deviceToken.deleteMany();
  await p.refreshToken.deleteMany();
  await p.user.deleteMany({ where: { role: { not: 'SUPER_ADMIN' } } });
  await p.user.updateMany({ data: { officeId: null } });
  await p.office.deleteMany();
  // Reset numbering so real data starts at SKET/<year>/00001, DID00001 and STF0001
  await p.$executeRawUnsafe('DELETE FROM sequence_counters');

  const counts = {
    users: await p.user.count(), donors: await p.donor.count(), donations: await p.donation.count(),
    students: await p.student.count(), staff: await p.staff.count(), expenses: await p.expense.count(), offices: await p.office.count(),
    centers: await p.center.count(), approvals: await p.approvalRequest.count(),
    donationTypes: await p.donationType.count(), expenseCategories: await p.expenseCategory.count(),
    paymentLinks: await p.paymentLink.count(), notifications: await p.notification.count(),
  };
  const kept = await p.user.findMany({ select: { email: true, role: true } });
  console.log('WIPE DONE', JSON.stringify(counts));
  console.log('KEPT USERS', JSON.stringify(kept));
  await p.$disconnect();
})().catch((e) => { console.error('WIPE FAIL:', e.message); process.exit(1); });
