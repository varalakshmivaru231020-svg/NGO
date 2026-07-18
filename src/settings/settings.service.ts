import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateWhatsappSettingsDto } from './dto/update-whatsapp-settings.dto';
import { UpdateRazorpaySettingsDto } from './dto/update-razorpay-settings.dto';
import { UpdateOrganizationSettingsDto } from './dto/update-organization-settings.dto';

const SINGLETON = 'singleton';

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  // Read (create-on-first-read) the singleton WhatsApp config row.
  async getWhatsapp() {
    const row = await this.prisma.whatsappSetting.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON },
      update: {},
    });
    return this.shape(row);
  }

  async updateWhatsapp(dto: UpdateWhatsappSettingsDto) {
    const data = {
      storeNumber: dto.storeNumber,
      phoneNumberId: dto.phoneNumberId,
      apiToken: dto.apiToken,
      apiUrl: dto.apiUrl,
      apiVersion: dto.apiVersion,
      wabaId: dto.wabaId,
      businessId: dto.businessId,
    };
    const row = await this.prisma.whatsappSetting.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON, ...data },
      update: data,
    });
    return this.shape(row);
  }

  private shape(row: any) {
    return {
      storeNumber: row.storeNumber ?? '',
      phoneNumberId: row.phoneNumberId ?? '',
      apiToken: row.apiToken ?? '',
      apiUrl: row.apiUrl ?? '',
      apiVersion: row.apiVersion ?? '',
      wabaId: row.wabaId ?? '',
      businessId: row.businessId ?? '',
      updatedAt: row.updatedAt,
    };
  }

  // Read (create-on-first-read) the singleton Razorpay config row.
  async getRazorpay() {
    const row = await this.prisma.razorpaySetting.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON },
      update: {},
    });
    return this.shapeRazorpay(row);
  }

  async updateRazorpay(dto: UpdateRazorpaySettingsDto) {
    const data = { keyId: dto.keyId, keySecret: dto.keySecret, webhookSecret: dto.webhookSecret };
    const row = await this.prisma.razorpaySetting.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON, ...data },
      update: data,
    });
    return this.shapeRazorpay(row);
  }

  private shapeRazorpay(row: any) {
    return {
      keyId: row.keyId ?? '',
      keySecret: row.keySecret ?? '',
      webhookSecret: row.webhookSecret ?? '',
      configured: !!(row.keyId && row.keySecret),
      updatedAt: row.updatedAt,
    };
  }

  // Read (create-on-first-read) the singleton organization identity row.
  async getOrganization() {
    const row = await this.prisma.orgSettings.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON },
      update: {},
    });
    return this.shapeOrganization(row);
  }

  async updateOrganization(dto: UpdateOrganizationSettingsDto) {
    const row = await this.prisma.orgSettings.upsert({
      where: { id: SINGLETON },
      create: { id: SINGLETON, ...dto },
      update: { ...dto },
    });
    return this.shapeOrganization(row);
  }

  private shapeOrganization(row: any) {
    return {
      name: row.name ?? '',
      address: row.address ?? '',
      city: row.city ?? '',
      state: row.state ?? '',
      country: row.country ?? '',
      pincode: row.pincode ?? '',
      phone: row.phone ?? '',
      email: row.email ?? '',
      website: row.website ?? '',
      registrationNumber: row.registrationNumber ?? '',
      pan: row.pan ?? '',
      reg12A: row.reg12A ?? '',
      cert80G: row.cert80G ?? '',
      fcra: row.fcra ?? '',
      logoBase64: row.logoBase64 ?? '',
      updatedAt: row.updatedAt,
    };
  }
}
