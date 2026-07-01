import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  async overview() {
    const now = new Date();
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalDonors,
      activeDonors,
      newDonorsThisMonth,
      totalStudents,
      activeStudents,
      yearlyDonations,
      monthlyDonations,
      totalRaised,
      byTier,
      byCategory,
      topDonors,
      donationsByType,
    ] = await Promise.all([
      this.prisma.donor.count(),
      this.prisma.donor.count({ where: { isActive: true } }),
      this.prisma.donor.count({ where: { createdAt: { gte: startOfMonth } } }),
      this.prisma.student.count(),
      this.prisma.student.count({ where: { status: 'ACTIVE' } }),
      this.prisma.donation.aggregate({ where: { date: { gte: startOfYear }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.donation.aggregate({ where: { date: { gte: startOfMonth }, status: 'COMPLETED' }, _sum: { amount: true }, _count: true }),
      this.prisma.donation.aggregate({ where: { status: 'COMPLETED' }, _sum: { amount: true } }),
      this.prisma.donor.groupBy({ by: ['tier'], _count: true }),
      this.prisma.donorCategory.findMany({ include: { _count: { select: { donors: true } } } }),
      this.prisma.donor.findMany({
        where: { isActive: true },
        select: { id: true, name: true, donorCode: true, tier: true, donations: { where: { status: 'COMPLETED' }, select: { amount: true } } },
        orderBy: { donations: { _count: 'desc' } },
        take: 10,
      }),
      this.prisma.donation.groupBy({ by: ['typeId'], _sum: { amount: true }, _count: true, where: { status: 'COMPLETED' } }),
    ]);

    const topDonorsWithTotal = topDonors.map((d) => ({
      ...d,
      total: d.donations.reduce((s, x) => s + x.amount, 0),
      donations: undefined,
    }));

    return {
      donors: { total: totalDonors, active: activeDonors, newThisMonth: newDonorsThisMonth, byTier },
      students: { total: totalStudents, active: activeStudents },
      donations: {
        totalRaised: totalRaised._sum.amount ?? 0,
        yearAmount: yearlyDonations._sum.amount ?? 0,
        yearCount: yearlyDonations._count,
        monthAmount: monthlyDonations._sum.amount ?? 0,
        monthCount: monthlyDonations._count,
      },
      topDonors: topDonorsWithTotal,
      byCategory,
      donationsByType,
    };
  }

  async monthlyTrend(months = 12) {
    const results: Array<{ month: string; label: string; amount: number; count: number }> = [];
    const now = new Date();
    for (let i = months - 1; i >= 0; i--) {
      const start = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 0);
      const agg = await this.prisma.donation.aggregate({
        where: { date: { gte: start, lte: end }, status: 'COMPLETED' },
        _sum: { amount: true },
        _count: true,
      });
      results.push({
        month: start.toISOString().substring(0, 7),
        label: start.toLocaleString('en-IN', { month: 'short' }),
        amount: agg._sum.amount ?? 0,
        count: agg._count,
      });
    }
    return results;
  }

  async donorRetention() {
    const now = new Date();
    const thisYear = now.getFullYear();
    const lastYear = thisYear - 1;

    const [thisYearDonors, lastYearDonors] = await Promise.all([
      this.prisma.donation.findMany({
        where: { date: { gte: new Date(thisYear, 0, 1) }, status: 'COMPLETED' },
        select: { donorId: true },
        distinct: ['donorId'],
      }),
      this.prisma.donation.findMany({
        where: { date: { gte: new Date(lastYear, 0, 1), lt: new Date(thisYear, 0, 1) }, status: 'COMPLETED' },
        select: { donorId: true },
        distinct: ['donorId'],
      }),
    ]);

    const thisYearSet = new Set(thisYearDonors.map((d) => d.donorId));
    const lastYearSet = new Set(lastYearDonors.map((d) => d.donorId));
    const retained = [...lastYearSet].filter((id) => thisYearSet.has(id)).length;
    const retentionRate = lastYearSet.size > 0 ? Math.round((retained / lastYearSet.size) * 100) : 0;

    return { thisYear: thisYearSet.size, lastYear: lastYearSet.size, retained, retentionRate };
  }
}
