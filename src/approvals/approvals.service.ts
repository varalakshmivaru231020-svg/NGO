import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ApprovalQueryDto } from './dto/approval-query.dto';

// Modules whose mutations must NEVER be funnelled through approval — auth and
// the approval system itself, plus per-user notification reads.
const EXEMPT_MODULES = new Set(['auth', 'approvals', 'notifications']);
const MUTATING = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);

// Document sub-resource routes are exempted at the PATH level, not the
// module level — 'students'/'users' stay approval-gated for every other
// mutation (profile edits, etc.), only their document upload/delete
// sub-routes bypass the queue so uploads save and appear immediately.
// Creating an expense category is a reference-data addition (a label), not a
// financial record — gating it behind approval only blocked the staff member
// from finishing the expense they were adding, for no real benefit.
const EXEMPT_PATH_PATTERNS: RegExp[] = [
  /^students\/[^/]+\/documents$/i,
  /^students\/documents\/[^/]+$/i,
  /^users\/[^/]+\/documents$/i,
  /^users\/documents\/[^/]+$/i,
  /^expenses\/categories$/i,
  // Donor media uploads (base64, up to ~27MB once encoded) — queueing them
  // copies the whole blob into ApprovalRequest.payload, which can exceed
  // MySQL's max_allowed_packet and kill the upload with an opaque 500.
  /^donors\/[^/]+\/activity-videos$/i,
  /^donors\/[^/]+\/activity-images$/i,
  // Changing your own password/profile must apply immediately, never queue.
  /^users\/me\/password$/i,
  /^users\/me\/profile$/i,
];

export interface SessionUser {
  id: string;
  name: string;
  email: string;
  role: string;
}

@Injectable()
export class ApprovalsService {
  private readonly logger = new Logger(ApprovalsService.name);
  // Secret marking an internal replay request so the interceptor lets it pass.
  readonly replaySecret = randomUUID();
  private readonly port: number;

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    config: ConfigService,
  ) {
    this.port = Number(config.get('PORT', 3001));
  }

  // ── interceptor helpers ────────────────────────────────────────────────
  shouldIntercept(req: any): boolean {
    const method = (req.method || '').toUpperCase();
    if (!MUTATING.has(method)) return false;
    const user = req.user as SessionUser | undefined;
    if (!user) return false; // unauthenticated → auth guard decides
    // ADMIN and SUPER_ADMIN act with full authority — they review approvals,
    // so their own mutations must not queue (they could self-approve anyway).
    if (user.role === 'SUPER_ADMIN' || user.role === 'ADMIN') return false;
    if (req.headers?.['x-approval-replay'] === this.replaySecret) return false; // replay
    const path = req.path || req.originalUrl || '';
    if (EXEMPT_MODULES.has(this.moduleOf(path))) return false;
    const relPath = this.relativeSegs(path).join('/');
    if (EXEMPT_PATH_PATTERNS.some((re) => re.test(relPath))) return false; // e.g. document uploads
    return true;
  }

  private relativeSegs(path: string): string[] {
    return path
      .split('?')[0]
      .replace(/^\/api\/v\d+\//, '')
      .split('/')
      .filter(Boolean);
  }

  private moduleOf(path: string): string {
    return this.relativeSegs(path)[0] ?? 'unknown';
  }

  private actionOf(method: string): 'CREATE' | 'EDIT' | 'DELETE' {
    if (method === 'POST') return 'CREATE';
    if (method === 'DELETE') return 'DELETE';
    return 'EDIT';
  }

  // ── create a pending request from an intercepted HTTP request ───────────
  async createFromRequest(req: any) {
    const user = req.user as SessionUser;
    const method = (req.method || '').toUpperCase();
    const path = (req.path || req.originalUrl || '').split('?')[0];
    const originalUrl = req.originalUrl || path;
    const segs = path.replace(/^\/api\/v\d+\//, '').split('/').filter(Boolean);
    const module = segs[0] ?? 'unknown';
    const action = this.actionOf(method);
    const targetId = action === 'CREATE' ? null : (segs[segs.length - 1] ?? null);

    // Best-effort snapshot of the current record for the diff view.
    let previousData: any = null;
    if (action !== 'CREATE' && targetId) {
      previousData = await this.fetchCurrent(path, req.headers?.authorization);
    }

    // Requester's office name → "department" for filtering.
    let department: string | null = null;
    try {
      const dbUser = await this.prisma.user.findUnique({
        where: { id: user.id },
        select: { office: { select: { name: true } } },
      });
      department = dbUser?.office?.name ?? null;
    } catch {
      // user may be a non-backed local account — leave department null
    }

    const created = await this.prisma.approvalRequest.create({
      data: {
        module,
        action,
        method,
        path: originalUrl,
        targetId,
        payload: this.toJson(req.body),
        previousData: this.toJson(previousData),
        status: 'PENDING',
        requesterId: user.id,
        requesterName: user.name ?? user.email,
        requesterRole: user.role,
        department,
      },
    });

    await this.notifySuperAdmins(created);
    return created;
  }

  private toJson(v: any): Prisma.InputJsonValue {
    if (v === null || v === undefined) return {} as Prisma.InputJsonValue;
    try {
      return JSON.parse(JSON.stringify(v)) as Prisma.InputJsonValue;
    } catch {
      return {} as Prisma.InputJsonValue;
    }
  }

  // ── internal HTTP (replay current-state fetch / approved execution) ─────
  private async internalCall(
    method: string,
    urlPath: string,
    body: any,
    authHeader?: string,
  ): Promise<{ ok: boolean; status: number; json: any }> {
    const url = `http://127.0.0.1:${this.port}${urlPath}`;
    const hasBody = method !== 'GET' && method !== 'DELETE';
    try {
      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          Authorization: authHeader ?? '',
          'x-approval-replay': this.replaySecret,
        },
        body: hasBody ? JSON.stringify(body ?? {}) : undefined,
      });
      const json = await res.json().catch(() => null);
      return { ok: res.ok, status: res.status, json };
    } catch (e: any) {
      this.logger.error(`internalCall ${method} ${urlPath} failed: ${e?.message}`);
      return { ok: false, status: 0, json: { message: e?.message ?? 'network error' } };
    }
  }

  private async fetchCurrent(path: string, authHeader?: string): Promise<any> {
    const res = await this.internalCall('GET', path, undefined, authHeader);
    if (!res.ok) return null;
    return res.json?.data ?? res.json ?? null;
  }

  // ── notifications ───────────────────────────────────────────────────────
  private async notifySuperAdmins(reqEntity: any) {
    try {
      const admins = await this.prisma.user.findMany({
        where: { role: { in: ['SUPER_ADMIN', 'ADMIN'] }, isActive: true },
        select: { id: true },
      });
      await Promise.all(
        admins.map((a) =>
          this.notifications.create({
            userId: a.id,
            title: `Approval needed · ${reqEntity.action} ${reqEntity.module}`,
            body: `${reqEntity.requesterName} (${reqEntity.requesterRole}) requested to ${reqEntity.action.toLowerCase()} in ${reqEntity.module}.`,
            icon: 'approval',
            route: '/approvals',
          }),
        ),
      );
    } catch (e: any) {
      this.logger.warn(`notifySuperAdmins failed: ${e?.message}`);
    }
  }

  private async notifyRequester(reqEntity: any, approved: boolean) {
    try {
      await this.notifications.create({
        userId: reqEntity.requesterId,
        title: approved
          ? `Approved · ${reqEntity.action} ${reqEntity.module}`
          : `Rejected · ${reqEntity.action} ${reqEntity.module}`,
        body: approved
          ? `Your request to ${reqEntity.action.toLowerCase()} in ${reqEntity.module} was approved and applied.`
          : `Your request to ${reqEntity.action.toLowerCase()} in ${reqEntity.module} was rejected. Reason: ${reqEntity.reason ?? '—'}`,
        icon: approved ? 'check' : 'close',
        route: '/approvals',
      });
    } catch (e: any) {
      this.logger.warn(`notifyRequester failed: ${e?.message}`);
    }
  }

  // ── queries ───────────────────────────────────────────────────────────
  async list(q: ApprovalQueryDto) {
    const where: Prisma.ApprovalRequestWhereInput = {};
    if (q.status) where.status = q.status.toUpperCase();
    if (q.module) where.module = q.module;
    if (q.action) where.action = q.action.toUpperCase();
    if (q.requesterId) where.requesterId = q.requesterId;
    if (q.role) where.requesterRole = q.role.toUpperCase();
    if (q.department) where.department = q.department;
    if (q.from || q.to) {
      where.createdAt = {};
      if (q.from) (where.createdAt as any).gte = new Date(q.from);
      if (q.to) (where.createdAt as any).lte = new Date(q.to);
    }
    if (q.q && q.q.trim()) {
      const term = q.q.trim();
      where.OR = [
        { requesterName: { contains: term } },
        { module: { contains: term } },
        { action: { contains: term } },
        { requesterRole: { contains: term } },
      ];
    }
    return this.prisma.approvalRequest.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 300,
    });
  }

  async stats() {
    const grouped = await this.prisma.approvalRequest.groupBy({
      by: ['status'],
      _count: { _all: true },
    });
    const out = { pending: 0, approved: 0, rejected: 0, total: 0 };
    for (const g of grouped) {
      const n = g._count._all;
      out.total += n;
      if (g.status === 'PENDING') out.pending = n;
      else if (g.status === 'APPROVED') out.approved = n;
      else if (g.status === 'REJECTED') out.rejected = n;
    }
    return out;
  }

  async findOne(id: string) {
    const r = await this.prisma.approvalRequest.findUnique({ where: { id } });
    if (!r) throw new NotFoundException('Approval request not found');
    return r;
  }

  async mine(userId: string) {
    return this.prisma.approvalRequest.findMany({
      where: { requesterId: userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  // ── decisions ─────────────────────────────────────────────────────────
  async approve(id: string, authHeader: string, reviewer: SessionUser) {
    const reqEntity = await this.findOne(id);
    if (reqEntity.status !== 'PENDING')
      throw new BadRequestException(`Request already ${reqEntity.status.toLowerCase()}`);

    // Replay the original mutation as the approving Super Admin.
    const result = await this.internalCall(
      reqEntity.method,
      reqEntity.path,
      reqEntity.payload,
      authHeader,
    );

    if (!result.ok) {
      const j = result.json ?? {};
      let msg =
        j.message || j.error || `Execution failed (HTTP ${result.status})`;
      // The global filter tucks validation details into `errors` and flattens
      // message to 'Validation failed' — include the details here.
      if (Array.isArray(j.errors) && j.errors.length)
        msg = `${msg}: ${j.errors.join('; ')}`;
      await this.prisma.approvalRequest.update({
        where: { id },
        data: { error: String(msg).slice(0, 480) },
      });
      throw new BadRequestException(
        `Could not apply this change: ${Array.isArray(msg) ? msg.join(', ') : msg}`,
      );
    }

    const resultId =
      result.json?.data?.id ?? result.json?.id ?? reqEntity.targetId ?? null;
    const updated = await this.prisma.approvalRequest.update({
      where: { id },
      data: {
        status: 'APPROVED',
        reviewerId: reviewer.id,
        reviewerName: reviewer.name ?? reviewer.email,
        reviewedAt: new Date(),
        resultId,
        error: null,
      },
    });
    await this.notifyRequester(updated, true);
    return updated;
  }

  async reject(id: string, reason: string, reviewer: SessionUser) {
    if (!reason || !reason.trim())
      throw new BadRequestException('A rejection reason is required');
    const reqEntity = await this.findOne(id);
    if (reqEntity.status !== 'PENDING')
      throw new BadRequestException(`Request already ${reqEntity.status.toLowerCase()}`);
    const updated = await this.prisma.approvalRequest.update({
      where: { id },
      data: {
        status: 'REJECTED',
        reason: reason.trim(),
        reviewerId: reviewer.id,
        reviewerName: reviewer.name ?? reviewer.email,
        reviewedAt: new Date(),
      },
    });
    await this.notifyRequester(updated, false);
    return updated;
  }

  async bulkApprove(ids: string[], authHeader: string, reviewer: SessionUser) {
    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const id of ids) {
      try {
        await this.approve(id, authHeader, reviewer);
        results.push({ id, ok: true });
      } catch (e: any) {
        results.push({ id, ok: false, error: e?.message ?? 'failed' });
      }
    }
    return {
      approved: results.filter((r) => r.ok).length,
      failed: results.filter((r) => !r.ok).length,
      results,
    };
  }

  async bulkReject(ids: string[], reason: string, reviewer: SessionUser) {
    if (!reason || !reason.trim())
      throw new BadRequestException('A rejection reason is required');
    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const id of ids) {
      try {
        await this.reject(id, reason, reviewer);
        results.push({ id, ok: true });
      } catch (e: any) {
        results.push({ id, ok: false, error: e?.message ?? 'failed' });
      }
    }
    return {
      rejected: results.filter((r) => r.ok).length,
      failed: results.filter((r) => !r.ok).length,
      results,
    };
  }

  // Guard helper — only SUPER_ADMIN may decide. (Controller also enforces this.)
  assertSuperAdmin(user: SessionUser) {
    if (user?.role !== 'SUPER_ADMIN')
      throw new ForbiddenException('Only the Super Admin can approve or reject');
  }
}
