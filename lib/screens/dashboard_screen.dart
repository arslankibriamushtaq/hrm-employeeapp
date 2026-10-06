import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'apply_leave_screen.dart';
import 'approvals_screen.dart';
import 'holidays_screen.dart';
import 'home_shell.dart';
import 'notifications_screen.dart';

class _DashboardData {
  Attendance? today;
  List<Attendance> thisMonth = [];
  List<LeaveQuota> quotas = [];
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
      api.myAttendance().then((rows) {
        data.thisMonth = rows.where((r) => r.date.year == now.year && r.date.month == now.month).toList();
        for (final r in rows) {
          if (isSameDay(r.date, now)) data.today = r;
        }
      }).catchError((Object e) {
        data.attendanceError = e.toString();
      }),
      api.myQuotas(now.year).then((q) => data.quotas = q).catchError((Object _) => <LeaveQuota>[]),
      api.pendingApprovals().then((p) => data.pendingApprovals = p.length).catchError((Object _) => 0),
      api.unreadCount().then((c) => data.unread = c).catchError((Object _) => 0),
      api.holidays().then((h) {
        final today = DateTime(now.year, now.month, now.day);
        data.upcomingHolidays = h.where((x) => !x.date.isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      }).catchError((Object _) {}),
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.bodySmall),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          FutureBuilder<_DashboardData>(
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
          ),
        ],
      ),
      body: AsyncBody<_DashboardData>(
        future: _future,
        onRetry: _refresh,
        builder: (context, data) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _TodayCard(data: data, onTap: () => widget.onOpenTab(Tabs.attendance)),
              if (data.pendingApprovals > 0) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text('${data.pendingApprovals} leave request${data.pendingApprovals == 1 ? '' : 's'} '
                        'waiting for you'),
                    subtitle: const Text('Review your team\'s requests'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const ApprovalsScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.add_circle_outline,
                      label: 'Apply leave',
                      onTap: () => _open(const ApplyLeaveScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.event_available_outlined,
                      label: 'Holidays',
                      onTap: () => _open(const HolidaysScreen()),
                    ),
                  ),
                ],
              ),
              SectionTitle('This month', trailing: Text(fmtMonth(DateTime.now()))),
              _MonthStats(rows: data.thisMonth),
              SectionTitle(
                'Leave balance ${DateTime.now().year}',
                trailing: TextButton(onPressed: () => widget.onOpenTab(Tabs.leave), child: const Text('View all')),
              ),
              if (data.quotas.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('No leave balance assigned yet'),
                    subtitle: Text('Contact HR if you think this is wrong.'),
                  ),
                )
              else
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.quotas.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _QuotaTile(quota: data.quotas[i]),
                  ),
                ),
              if (data.upcomingHolidays.isNotEmpty) ...[
                const SectionTitle('Upcoming holidays'),
                Card(
                  child: Column(
                    children: [
                      for (final h in data.upcomingHolidays.take(3))
                        ListTile(
                          leading: const Icon(Icons.celebration_outlined),
                          title: Text(h.name),
                          subtitle: Text(fmtShortDate(h.date)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
      status = 'No attendance recorded yet today';
    } else if (today.checkOut == null) {
      status = 'Checked in';
    } else {
      status = 'Day complete';
    }

    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text('Today · ${fmtShortDate(DateTime.now())}',
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (today?.late == true)
                    StatusChip('LATE', label: today!.lateExcused ? 'Late (excused)' : 'Late ${today.lateMinutes ?? ''}m'),
                ],
              ),
              const SizedBox(height: 12),
              Text(status,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TimeBlock(label: 'Check in', value: fmtTime(today?.checkIn), color: scheme.onPrimaryContainer),
                  _TimeBlock(label: 'Check out', value: fmtTime(today?.checkOut), color: scheme.onPrimaryContainer),
                  _TimeBlock(label: 'Worked', value: fmtHours(today?.totalHours), color: scheme.onPrimaryContainer),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.75), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
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
    return Row(
      children: [
        _Stat(value: '$present', label: 'Days present'),
        const SizedBox(width: 8),
        _Stat(value: fmtHours(hours), label: 'Hours worked'),
        const SizedBox(width: 8),
        _Stat(value: '$late', label: 'Late days'),
        const SizedBox(width: 8),
        _Stat(value: fmtHours(shortHours), label: 'Short hours'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              FittedBox(
                child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaTile extends StatelessWidget {
  const _QuotaTile({required this.quota});

  final LeaveQuota quota;

  @override
  Widget build(BuildContext context) {
    final ratio = quota.totalQuota == 0 ? 0.0 : quota.remainingQuota / quota.totalQuota;
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(quota.leaveTypeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${quota.remainingQuota}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                TextSpan(text: ' / ${quota.totalQuota} left'),
              ])),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
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
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
