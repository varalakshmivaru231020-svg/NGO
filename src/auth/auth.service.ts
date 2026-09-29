import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async login(dto: LoginDto, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !user.isActive) throw new UnauthorizedException('Invalid credentials');

    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return this.generateTokens(user.id, user.email, user.role, userAgent);
  }

  // The caller's own login/session history (newest first) for the Security
  // screen — real data instead of the old hardcoded rows.
  async sessions(userId: string) {
    return this.prisma.refreshToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 15,
      select: { createdAt: true, userAgent: true, expiresAt: true },
    });
  }

  // Rotation with a short grace window: the old token stays usable for
  // REFRESH_GRACE_MS instead of being deleted outright. Several requests (or
  // two browser tabs) that hit a 401 at the same moment each try to refresh
  // with the same token; deleting it on the first call made every other
  // caller fail and sign the user out mid-work.
  async refresh(userId: string, email: string, role: string, oldToken: string, userAgent?: string) {
    const graceUntil = new Date(Date.now() + AuthService.REFRESH_GRACE_MS);
    await this.prisma.refreshToken.updateMany({
      where: { token: oldToken, expiresAt: { gt: graceUntil } },
      data: { expiresAt: graceUntil },
    });
    return this.generateTokens(userId, email, role, userAgent);
  }

  private static readonly REFRESH_GRACE_MS = 2 * 60 * 1000;

  async logout(userId: string, refreshToken: string) {
    // Scoped to the caller — otherwise any authenticated user could revoke
    // arbitrary refresh tokens they've obtained.
    await this.prisma.refreshToken.deleteMany({ where: { token: refreshToken, userId } });
    return { message: 'Logged out successfully' };
  }

  async me(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, email: true, role: true, modules: true, phone: true, avatar: true, office: true },
    });
  }

  private async generateTokens(userId: string, email: string, role: any, userAgent?: string) {
    // jti makes every token unique — without it two tokens issued for the
    // same user in the same second were byte-identical, and the second
    // insert hit RefreshToken.token's unique index (500 → forced logout).
    const payload = { sub: userId, email, role, jti: randomUUID() };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_SECRET'),
      expiresIn: this.configService.get('JWT_EXPIRES_IN', '15m'),
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN', '7d'),
    });

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await this.prisma.refreshToken.create({
      data: { token: refreshToken, userId, expiresAt, userAgent: userAgent?.slice(0, 250) },
    });

    // Clean up expired tokens
    await this.prisma.refreshToken.deleteMany({
      where: { userId, expiresAt: { lt: new Date() } },
    });

    return { accessToken, refreshToken, tokenType: 'Bearer' };
  }
}
