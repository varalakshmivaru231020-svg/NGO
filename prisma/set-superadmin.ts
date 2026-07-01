// One-off: establish a single fresh SUPER_ADMIN and remove the old demo ones.
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const EMAIL = 'admin@sket.org';
const PASSWORD = 'Sket@2026';

async function main() {
  const passwordHash = await argon2.hash(PASSWORD);
  await prisma.user.upsert({
    where: { email: EMAIL },
    update: { role: 'SUPER_ADMIN', isActive: true, passwordHash, name: 'Super Admin' },
    create: { email: EMAIL, name: 'Super Admin', passwordHash, role: 'SUPER_ADMIN' },
  });

  // Remove the old demo super admins.
  const old = ['Vara@gmail.com', 'admin@saksham.org'];
  await prisma.refreshToken.deleteMany({ where: { user: { email: { in: old } } } });
  await prisma.user.deleteMany({ where: { email: { in: old } } });

  const users = await prisma.user.findMany({ select: { email: true, role: true, isActive: true } });
  console.log('USERS NOW ' + JSON.stringify(users));
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
