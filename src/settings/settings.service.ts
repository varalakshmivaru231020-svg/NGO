import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateWhatsappSettingsDto } from './dto/update-whatsapp-settings.dto';

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
}
