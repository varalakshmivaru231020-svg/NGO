import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateUserDocumentDto } from './dto/create-user-document.dto';
import { PaginationDto, paginate, paginatedResponse } from '../common/dto/pagination.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  private select = {
    id: true, name: true, email: true, role: true, modules: true, phone: true,
    avatar: true, isActive: true, lastLoginAt: true, createdAt: true,
    office: { select: { id: true, name: true, city: true } },
  };

  async create(dto: CreateUserDto) {
    const exists = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (exists) throw new ConflictException('Email already registered');
    const passwordHash = await argon2.hash(dto.password);
    const { password: _pw, ...userData } = dto as any;
    return this.prisma.user.create({
      data: { ...userData, passwordHash },
      select: this.select,
    });
  }

  async findAll(query: PaginationDto) {
    const { page = 1, limit = 20, search } = query;
    const where = search ? {
      OR: [
        { name: { contains: search, mode: 'insensitive' as const } },
        { email: { contains: search, mode: 'insensitive' as const } },
      ],
    } : {};
    const [data, total] = await Promise.all([
      this.prisma.user.findMany({ where, select: this.select, ...paginate(page, limit), orderBy: { createdAt: 'desc' } }),
      this.prisma.user.count({ where }),
    ]);
    return paginatedResponse(data, total, page, limit);
  }

  // Lightweight list of active staff for "pick a person" pickers (e.g. the
  // Expense "Approved By" dropdown) — deliberately leaner than findAll()'s
  // full projection, and reachable by any authenticated user (see controller)
  // rather than gating it behind the ADMIN-only user-management endpoint.
  async findApprovers() {
    return this.prisma.user.findMany({
      where: { isActive: true },
      select: { id: true, name: true, role: true },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id }, select: this.select });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);
    return this.prisma.user.update({ where: { id }, data: dto, select: this.select });
  }

  async toggleActive(id: string) {
    const user = await this.findOne(id);
    return this.prisma.user.update({
      where: { id },
      data: { isActive: !user.isActive },
      select: this.select,
    });
  }

  async changePassword(id: string, newPassword: string) {
    const passwordHash = await argon2.hash(newPassword);
    await this.prisma.user.update({ where: { id }, data: { passwordHash } });
    return { message: 'Password updated' };
  }

  // Soft-delete a team member: deactivate (login checks isActive) and revoke
  // every refresh token so any existing session can't be renewed. Deterministic
  // (always disables) — unlike toggleActive — so a deleted member can never log
  // in again.
  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.refreshToken.deleteMany({ where: { userId: id } });
    const user = await this.prisma.user.update({
      where: { id },
      data: { isActive: false },
      select: this.select,
    });
    return { ...user, deleted: true };
  }

  // ── Staff/own-profile documents — mirrors StudentsService's document
  // methods (same base64-in-JSON storage approach). Access control (self or
  // ADMIN) is enforced in the controller since it isn't a pure role check.
  async addDocument(userId: string, dto: CreateUserDocumentDto) {
    await this.findOne(userId);
    return this.prisma.userDocument.create({
      data: { userId, category: dto.category, fileName: dto.fileName, mimeType: dto.mimeType, data: dto.data },
      select: { id: true, userId: true, category: true, fileName: true, mimeType: true, createdAt: true },
    });
  }

  async getDocuments(userId: string) {
    return this.prisma.userDocument.findMany({
      where: { userId },
      select: { id: true, userId: true, category: true, fileName: true, mimeType: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getDocument(docId: string) {
    const doc = await this.prisma.userDocument.findUnique({ where: { id: docId } });
    if (!doc) throw new NotFoundException('Document not found');
    return doc;
  }

  async removeDocument(docId: string) {
    return this.prisma.userDocument.delete({ where: { id: docId } });
  }
}
