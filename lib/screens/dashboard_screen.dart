import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../session.dart';
import '../theme/brand.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/home_header.dart';
import 'apply_leave_screen.dart';
import 'approvals_screen.dart';
import 'holidays_screen.dart';
import 'home_shell.dart';
import 'notifications_screen.dart';

class _DashboardData {
  Attendance? today;
  List<Attendance> thisMonth = [];
  List<LeaveQuota> quotas = [];
  ApproverKind? approver;
  int pendingApprovals = 0;
  int unread = 0;
  List<Holiday> upcomingHolidays = [];
  String? attendanceError;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Each section loads independently, so one failing call (e.g. no quota assigned yet)
  /// does not blank the whole screen.
  Future<_DashboardData> _load() async {
    final api = AppScope.read(context).api;
    final now = DateTime.now();
    final data = _DashboardData();

    await Future.wait([
      // The backend returns the whole history; today's row (if any) is picked out here.
      // No row for today is a normal state, not an error.
      api.myAttendance().then((rows) {
        data.thisMonth = rows.where((r) => r.date.year == now.year && r.date.month == now.month).toList();
        for (final r in rows) {
          if (isSameDay(r.date, now)) data.today = r;
        }
      }).catchError((Object e) {
        debugPrint('Dashboard: attendance failed: $e');
        data.attendanceError = e.toString();
      }),
      api.myQuotas(now.year).then((q) => data.quotas = q).catchError((Object e) {
        debugPrint('Dashboard: leave quotas failed: $e');
        return <LeaveQuota>[];
      }),
      // Same rule as the Profile entry: only HR / team leads get the "waiting for you"
      // card, and others never call the pending list.
      approverKind(AppScope.read(context)).then((kind) async {
        data.approver = kind;
        if (kind != null) data.pendingApprovals = (await api.pendingApprovals()).length;
      }).catchError((Object e) {
        debugPrint('Dashboard: approval access / pending approvals failed: $e');
      }),
      api.unreadCount().then((c) => data.unread = c).catchError((Object e) {
        debugPrint('Dashboard: unread count failed: $e');
        return 0;
      }),
      api.holidays().then((h) {
        final today = DateTime(now.year, now.month, now.day);
        data.upcomingHolidays = h.where((x) => !x.date.isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      }).catchError((Object e) {
        debugPrint('Dashboard: holidays failed: $e');
      }),
    ]);
    return data;
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() { _future = f; });
    await f;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final name = (user?.email ?? '').split('@').first;

    final bell = FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snap) {
        final unread = snap.data?.unread ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(const NotificationsScreen()),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );

    // No AppBar: the two-line header sizes itself, so a large text scale cannot overflow
    // a fixed toolbar height. Dark status-bar icons, as the AppBar gave on white.
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              HomeHeader(greeting: _greeting(), name: name, trailing: bell),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return AsyncBody<_DashboardData>(
      future: _future,
      onRetry: _refresh,
      skeleton: const _HomeSkeleton(),
      builder: (context, data) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
          children: [
            _TodayCard(data: data, onTap: () => widget.onOpenTab(Tabs.attendance)),
            if (data.approver case final approver? when data.pendingApprovals > 0) ...[
              const SizedBox(height: Space.md),
              AppCard(
                onTap: () => _open(ApprovalsScreen(kind: approver)),
                child: Row(
                  children: [
                    const IconBubble(Icons.how_to_reg_outlined, color: AppColors.pending),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data.pendingApprovals} leave request${data.pendingApprovals == 1 ? '' : 's'} '
                            'waiting for you',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text('Review your team\'s requests',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Apply leave',
                    onTap: () => _open(const ApplyLeaveScreen()),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.event_available_outlined,
                    label: 'Holidays',
                    onTap: () => _open(const HolidaysScreen()),
                  ),
                ),
              ],
            ),
            SectionHeader(
              'This month',
              trailing: Text(fmtMonth(DateTime.now()),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            _MonthStats(rows: data.thisMonth),
            SectionHeader(
              'Leave balance ${DateTime.now().year}',
              trailing: TextButton(onPressed: () => widget.onOpenTab(Tabs.leave), child: const Text('View all')),
            ),
            if (data.quotas.isEmpty)
              const AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No leave balance assigned yet'),
                  subtitle: Text('Contact HR if you think this is wrong.'),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < data.quotas.length; i++) ...[
                      if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                      _QuotaRow(quota: data.quotas[i]),
                    ],
                  ],
                ),
              ),
            if (data.upcomingHolidays.isNotEmpty) ...[
              const SectionHeader('Upcoming holidays'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, h) in data.upcomingHolidays.take(3).indexed) ...[
                      if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                        child: Row(
                          children: [
                            DateBadge(date: h.date, caption: fmtMonthShort(h.date)),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.name, style: Theme.of(context).textTheme.titleSmall),
                                  Text(fmtShortDate(h.date),
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder in the shape of the Home content.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget pair(double height) => Row(
          children: [
            Expanded(child: SkeletonBox(height: height, radius: Radii.card)),
            const SizedBox(width: Space.md),
            Expanded(child: SkeletonBox(height: height, radius: Radii.card)),
          ],
        );
    return LoadingSkeleton(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
      children: [
        const SkeletonBox(height: 168, radius: Radii.card),
        pair(96),
        const SkeletonBox(width: 120, height: 20),
        pair(68),
        pair(68),
        const SkeletonBox(width: 160, height: 20),
        const SkeletonBox(height: 140, radius: Radii.card),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data, required this.onTap});

  final _DashboardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = data.today;
    final String status;
    if (data.attendanceError != null) {
      status = 'Could not load attendance';
    } else if (today == null) {
      status = 'No record for today';
    } else if (today.checkOut == null) {
      status = 'Checked in';
    } else {
      status = 'Day complete';
    }
    // Short already includes late time, so a day shows Late until check-out and only
    // Short after it. shortHours is in hours and is 0.0 before check-out.
    StatusChip? badge;
    if (today != null && today.checkOut == null) {
      if (today.late && (today.lateMinutes ?? 0) > 0) {
        badge = StatusChip(today.lateExcused ? 'APPROVED' : 'PENDING',
            label: today.lateExcused ? 'Late (excused)' : fmtLate(today.lateMinutes));
      }
    } else if (today != null) {
      final shortHours = today.shortHours ?? 0;
      // The red tone keeps Short apart from the orange Late chip.
      if ((shortHours * 60).round() > 0) badge = StatusChip('ABSENT', label: 'Short ${fmtHours(shortHours)}');
    }

    return Card(
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg + Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBubble(Icons.today, size: 36),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text('Today · ${fmtShortDate(DateTime.now())}',
                          style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                    ),
                    if (badge != null) badge,
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(status,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                const SizedBox(height: Space.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.md),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Row(
                    children: [
                      _TimeBlock(label: 'Check in', value: fmtTime(today?.checkIn)),
                      _TimeBlock(label: 'Check out', value: fmtTime(today?.checkOut)),
                      _TimeBlock(label: 'Worked', value: fmtHours(today?.totalHours)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _MonthStats extends StatelessWidget {
  const _MonthStats({required this.rows});

  final List<Attendance> rows;

  @override
  Widget build(BuildContext context) {
    final present = rows.length;
    final hours = rows.fold<double>(0, (sum, r) => sum + (r.totalHours ?? 0));
    final late = rows.where((r) => r.late && !r.lateExcused).length;
    final shortHours = rows.fold<double>(0, (sum, r) => sum + (r.shortHours ?? 0));
    // Two per row: four across leaves no room for labels at 360dp or large text.
    return Column(
      children: [
        Row(
          children: [
            _Stat(icon: Icons.event_available_outlined, color: AppColors.approved, value: '$present', label: 'Days present'),
            const SizedBox(width: Space.md),
            _Stat(icon: Icons.schedule, color: AppColors.red, value: fmtHours(hours), label: 'Hours worked'),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            _Stat(icon: Icons.alarm, color: AppColors.pending, value: '$late', label: 'Late days'),
            const SizedBox(width: Space.md),
            _Stat(icon: Icons.timelapse, color: AppColors.rejected, value: fmtHours(shortHours), label: 'Short hours'),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            IconBubble(icon, color: color, size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text(label,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.quota});

  final LeaveQuota quota;

  @override
  Widget build(BuildContext context) {
    final ratio = quota.totalQuota == 0 ? 0.0 : quota.remainingQuota / quota.totalQuota;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(quota.leaveTypeName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(width: Space.sm),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${quota.remainingQuota}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextSpan(
                  text: ' / ${quota.totalQuota} left',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ])),
            ],
          ),
          const SizedBox(height: Space.sm),
          LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.md),
      child: Column(
        children: [
          IconBubble(icon, size: 44),
          const SizedBox(height: Space.sm),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
