import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentLinkDto } from './dto/create-payment-link.dto';
import { randomBytes } from 'crypto';

@Injectable()
export class PaymentLinksService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreatePaymentLinkDto) {
    const slug = randomBytes(8).toString('hex');
    return this.prisma.paymentLink.create({
      data: { ...dto, slug, expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined },
    });
  }

  async findAll() {
    return this.prisma.paymentLink.findMany({
      orderBy: { createdAt: 'desc' },
      include: { donation: { include: { donor: { select: { id: true, name: true } } } } },
    });
  }

  async findBySlug(slug: string) {
    const link = await this.prisma.paymentLink.findUnique({ where: { slug } });
    if (!link) throw new NotFoundException('Payment link not found');
    return link;
  }

  async expire(id: string) {
    return this.prisma.paymentLink.update({ where: { id }, data: { status: 'EXPIRED' } });
  }
}
