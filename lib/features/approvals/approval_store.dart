import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

// Live pending-approvals count for the sidebar badge (GET /approvals/stats is
// Super-Admin only, matching who can even see the Approvals nav item).
// Refreshed whenever the sidebar renders it and whenever the Approvals screen
// itself loads or acts on a request, so the badge tracks the real queue
// without needing a full shell remount.
final pendingApprovalsCount = ValueNotifier<int>(0);

Future<void> refreshPendingApprovalsCount() async {
  try {
    final r = await apiClient.get('/approvals/stats');
    final d = (r['data'] as Map?)?.cast<String, dynamic>();
    pendingApprovalsCount.value = (d?['pending'] as int?) ?? 0;
  } catch (_) {}
}
