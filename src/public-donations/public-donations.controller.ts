import { Controller, Get, Post, Body, Param, ServiceUnavailableException } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PublicDonationsService } from './public-donations.service';
import { CreatePublicDonationDto } from './dto/create-public-donation.dto';

// Genuinely public/unauthenticated — intentionally no @UseGuards here. This
// is the public website's donate flow; auth guards in this codebase are
// applied per-controller, so simply omitting @UseGuards is what makes a
// controller public (see src/app.module.ts — there is no global auth guard).
@ApiTags('public-donations')
@Controller('public/donations')
export class PublicDonationsController {
  constructor(private svc: PublicDonationsService) {}

  @Post('initiate')
  @ApiOperation({ summary: 'Start a public website donation — creates/finds the donor and a Razorpay payment link' })
  async initiate(@Body() dto: CreatePublicDonationDto) {
    const result = await this.svc.initiate(dto);
    if (!result.success) {
      throw new ServiceUnavailableException({
        code: 'GATEWAY_NOT_CONFIGURED',
        message: 'Online donations are temporarily unavailable — please contact us directly.',
      });
    }
    return { razorpayShortUrl: result.razorpayShortUrl, slug: result.slug };
  }

  @Get(':slug/status')
  @ApiOperation({ summary: 'Poll a public payment link’s status by slug (public)' })
  getStatus(@Param('slug') slug: string) {
    return this.svc.getStatusBySlug(slug);
  }
}
