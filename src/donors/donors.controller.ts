import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { DonorsService } from './donors.service';
import { CreateDonorDto } from './dto/create-donor.dto';
import { UpdateDonorDto } from './dto/update-donor.dto';
import { DonorQueryDto } from './dto/donor-query.dto';
import { ImportDonorsDto } from './dto/import-donors.dto';
import { CreateDonorActivityVideoDto } from './dto/create-donor-activity-video.dto';
import { CreateDonorActivityImageDto } from './dto/create-donor-activity-image.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@ApiTags('donors')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('donors')
export class DonorsController {
  constructor(private svc: DonorsService) {}

  @Get('summary') @ApiOperation({ summary: 'Donor summary stats' })
  summary() { return this.svc.summary(); }

  @Post() @ApiOperation({ summary: 'Create donor' })
  create(@Body() dto: CreateDonorDto) { return this.svc.create(dto); }

  // ADMIN-only (RolesGuard): a 500-row payload has no place in the approval
  // queue, and admins bypass the interceptor anyway.
  @Post('import') @Roles('ADMIN') @ApiOperation({ summary: 'Bulk import donors from a spreadsheet; per-row results' })
  importMany(@Body() dto: ImportDonorsDto) { return this.svc.importMany(dto); }

  @Get() @ApiOperation({ summary: 'List donors' })
  findAll(@Query() q: DonorQueryDto) { return this.svc.findAll(q); }

  @Get(':id/avatar') @ApiOperation({ summary: 'Donor photo only (list rows omit it)' })
  avatar(@Param('id') id: string) { return this.svc.getAvatar(id); }

  @Get(':id') @ApiOperation({ summary: 'Get donor by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update donor' })
  update(@Param('id') id: string, @Body() dto: UpdateDonorDto) { return this.svc.update(id, dto); }

  @Delete(':id') @ApiOperation({ summary: 'Soft-delete donor' })
  remove(@Param('id') id: string) { return this.svc.remove(id); }

  @Post(':id/activity-videos') @ApiOperation({ summary: 'Upload a donor activity video' })
  addActivityVideo(@Param('id') id: string, @Body() dto: CreateDonorActivityVideoDto) {
    return this.svc.addActivityVideo(id, dto);
  }

  @Get(':id/activity-videos') @ApiOperation({ summary: 'List activity video metadata (no file content)' })
  getActivityVideos(@Param('id') id: string) {
    return this.svc.getActivityVideos(id);
  }

  @Get('activity-videos/:videoId') @ApiOperation({ summary: 'Get an activity video with its file content' })
  getActivityVideo(@Param('videoId') videoId: string) {
    return this.svc.getActivityVideo(videoId);
  }

  @Delete('activity-videos/:videoId') @ApiOperation({ summary: 'Remove an activity video' })
  removeActivityVideo(@Param('videoId') videoId: string) {
    return this.svc.removeActivityVideo(videoId);
  }

  @Post(':id/activity-images') @ApiOperation({ summary: 'Upload a donor activity image' })
  addActivityImage(@Param('id') id: string, @Body() dto: CreateDonorActivityImageDto) {
    return this.svc.addActivityImage(id, dto);
  }

  @Get(':id/activity-images') @ApiOperation({ summary: 'List activity image metadata (no file content)' })
  getActivityImages(@Param('id') id: string) {
    return this.svc.getActivityImages(id);
  }

  @Get('activity-images/:imageId') @ApiOperation({ summary: 'Get an activity image with its file content' })
  getActivityImage(@Param('imageId') imageId: string) {
    return this.svc.getActivityImage(imageId);
  }

  @Delete('activity-images/:imageId') @ApiOperation({ summary: 'Remove an activity image' })
  removeActivityImage(@Param('imageId') imageId: string) {
    return this.svc.removeActivityImage(imageId);
  }
}
