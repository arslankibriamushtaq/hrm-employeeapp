import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../theme/brand.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'approvals_screen.dart';
import 'leave_screen.dart';

/// What a notification is about. The backend sends no type field, so this is read from
/// the message text - adjust the phrases here if the backend wording changes.
enum NotificationKind {
  /// "... requested ..." - an approver (team lead / HR) has a request to decide.
  approvalRequest,

  /// "... was approved" / "... was rejected" - the applicant's result.
  decisionResult,

  unknown,
}

/// The result phrases are checked first: they are the more specific match.
NotificationKind notificationKind(String message) {
  final m = message.toLowerCase();
  if (m.contains('was approved') || m.contains('was rejected')) return NotificationKind.decisionResult;
  if (m.contains('requested')) return NotificationKind.approvalRequest;
  return NotificationKind.unknown;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  /// Notification whose leave request is being looked up (shows a spinner on its row).
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final list = await AppScope.read(context).api.notifications();
    list.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return list;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final f = _load();
    setState(() { _future = f; });
    await f.catchError((Object _) => <AppNotification>[]);
  }

  Future<void> _markAllRead() async {
    try {
      await AppScope.read(context).api.markAllRead();
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    try {
      await AppScope.read(context).api.markRead(n.id);
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  /// Marks the notification read, then deep-links to its leave request if it has one.
  Future<void> _onTap(AppNotification n) async {
    if (_openingId != null) return;
    await _markRead(n);
    final leaveId = n.relatedLeaveId;
    if (leaveId == null || !mounted) return;
    setState(() => _openingId = n.id);
    try {
      await _openLeave(notificationKind(n.message), leaveId);
    } catch (e) {
      debugPrint('Notifications: loading leave request $leaveId failed: $e');
      if (mounted) showSnack(context, 'Request load nahi ho saki, dobara try karein', error: true);
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  /// GET /leave-requests/{id} is HR-only, so the request is found in the caller's own
  /// lists, fetched fresh on every tap. Each list is only fetched if still needed.
  Future<void> _openLeave(NotificationKind kind, String id) async {
    final session = AppScope.read(context);
    final api = session.api;
    LeaveRequest? find(List<LeaveRequest> rows) {
      for (final r in rows) {
        if (r.id == id) return r;
      }
      return null;
    }

    Future<bool> openApprovals() async {
      final title = approverKind(session);
      final tab = find(await api.pendingApprovals()) != null
          ? 0
          : find(await api.decidedApprovals()) != null
              ? 1
              : null;
      if (tab == null) return false;
      final approver = await title ?? ApproverKind.teamLead;
      if (mounted) _push(ApprovalsScreen(kind: approver, initialTab: tab, highlightId: id));
      return true;
    }

    Future<bool> openMine() async {
      final r = find(await api.myLeaveRequests());
      if (r == null) return false;
      if (mounted) {
        // Leave screen on top of Notifications, its detail sheet on top of that, so Back
        // walks sheet -> My requests -> Notifications.
        _push(const LeaveScreen());
        showLeaveDetails(context, r);
      }
      return true;
    }

    switch (kind) {
      case NotificationKind.approvalRequest:
        if (!await openApprovals() && mounted) {
          showSnack(context, 'Yeh request ab aap ke paas nahi hai (shayad pehle hi decide ho chuki hai)');
        }
      case NotificationKind.decisionResult:
        if (!await openMine() && mounted) showSnack(context, 'Yeh leave request nahi mili');
      case NotificationKind.unknown:
        if (!await openMine() && !await openApprovals() && mounted) {
          showSnack(context, 'Yeh leave request nahi mili');
        }
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Icon and colour by what the notification is about (same wording rules as the deep
  /// link). Read notifications go grey so unread ones stand out.
  (IconData, Color) _iconFor(AppNotification n, ColorScheme scheme) {
    final (icon, color) = switch (notificationKind(n.message)) {
      NotificationKind.approvalRequest => (Icons.how_to_reg_outlined, AppColors.pending),
      NotificationKind.decisionResult => n.message.toLowerCase().contains('was rejected')
          ? (Icons.cancel_outlined, AppColors.rejected)
          : (Icons.check_circle_outline, AppColors.approved),
      NotificationKind.unknown => n.relatedLeaveId != null
          ? (Icons.event_note_outlined, scheme.primary)
          : (Icons.notifications_outlined, scheme.primary),
    };
    return (icon, n.read ? scheme.onSurfaceVariant : color);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _markAllRead, child: const Text('Mark all read')),
        ],
      ),
      body: AsyncBody<List<AppNotification>>(
        future: _future,
        onRetry: _refresh,
        skeleton: LoadingSkeleton.list(count: 6, itemHeight: 72),
        builder: (context, items) => RefreshIndicator(
          onRefresh: _refresh,
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(icon: Icons.notifications_none, message: 'You are all caught up.'),
                ])
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    final (icon, color) = _iconFor(n, scheme);
                    return ListTile(
                      onTap: () => _onTap(n),
                      tileColor: n.read ? null : scheme.primaryContainer.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
                      leading: IconBubble(icon, color: color),
                      title: Text(n.message,
                          style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w600)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(fmtDateTime(n.createdAt), style: const TextStyle(fontSize: 12)),
                      ),
                      trailing: _openingId == n.id
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : n.read
                              ? null
                              : Semantics(
                                  label: 'Unread',
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                                  ),
                                ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
