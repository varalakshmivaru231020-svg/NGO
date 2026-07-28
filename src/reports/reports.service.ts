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
      // Rank by COMPLETED amount — ranking by donation _count included
      // failed/pending rows, so a donor with 40 failed attempts topped the
      // board with a displayed total of 0.
      this.prisma.donation.groupBy({
        by: ['donorId'],
        where: { status: 'COMPLETED' },
        _sum: { amount: true },
        orderBy: { _sum: { amount: 'desc' } },
        take: 10,
      }),
      this.prisma.donation.groupBy({ by: ['typeId'], _sum: { amount: true }, _count: true, where: { status: 'COMPLETED' } }),
    ]);

    const donorRows = await this.prisma.donor.findMany({
      where: { id: { in: topDonors.map((g) => g.donorId) }, isActive: true },
      select: { id: true, name: true, donorCode: true, tier: true },
    });
    const donorById = new Map(donorRows.map((d) => [d.id, d]));
    const topDonorsWithTotal = topDonors
      .filter((g) => donorById.has(g.donorId))
      .map((g) => ({ ...donorById.get(g.donorId)!, total: g._sum.amount ?? 0 }));

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
    // Clamp — the query param arrives unvalidated, and each month is one
    // sequential aggregate query.
    const n = Math.min(24, Math.max(1, Math.floor(months) || 12));
    const results: Array<{ month: string; label: string; amount: number; count: number }> = [];
    const now = new Date();
    for (let i = n - 1; i >= 0; i--) {
      const start = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 1); // exclusive
      const agg = await this.prisma.donation.aggregate({
        where: { date: { gte: start, lt: end }, status: 'COMPLETED' },
        _sum: { amount: true },
        _count: true,
      });
      results.push({
        // Local date parts — toISOString() shifts local midnight into the
        // previous month for any UTC-ahead timezone (IST labels were off by one).
        month: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`,
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
