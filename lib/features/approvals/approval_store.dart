import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

// Live pending-approvals count for the sidebar badge (GET /approvals/stats is
// Super-Admin only, matching who can even see the Approvals nav item).
// Refreshed whenever the sidebar renders it and whenever the Approvals screen
// itself loads or acts on a request, so the badge tracks the real queue
// without needing a full shell remount.
final pendingApprovalsCount = ValueNotifier<int>(0);

DateTime? _lastRefresh;

Future<void> refreshPendingApprovalsCount({bool force = false}) async {
  // Called from the sidebar's build() — throttle so rebuilds don't turn into
  // a request storm against /approvals/stats.
  final now = DateTime.now();
  if (!force && _lastRefresh != null && now.difference(_lastRefresh!) < const Duration(seconds: 30)) {
    return;
  }
  _lastRefresh = now;
  try {
    final r = await apiClient.get('/approvals/stats');
    final d = (r['data'] as Map?)?.cast<String, dynamic>();
    pendingApprovalsCount.value = (d?['pending'] as int?) ?? 0;
  } catch (_) {}
}
