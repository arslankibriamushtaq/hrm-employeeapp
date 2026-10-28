import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../theme/brand.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class _AttendanceData {
  _AttendanceData(this.rows, this.holidays);

  final List<Attendance> rows;
  final Map<DateTime, String> holidays;
}

/// The employee's own attendance (GET /me/attendance-records), browsed month by month.
/// Attendance is recorded by HR / the biometric import - there is no self check-in.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<_AttendanceData> _future;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttendanceData> _load() async {
    final api = AppScope.read(context).api;
    final results = await Future.wait([
      api.myAttendance(),
      api.holidays().catchError((Object _) => <Holiday>[]),
    ]);
    final rows = results[0] as List<Attendance>;
    final holidays = results[1] as List<Holiday>;
    rows.sort((a, b) => b.date.compareTo(a.date));
    return _AttendanceData(rows, {
      for (final h in holidays) DateTime(h.date.year, h.date.month, h.date.day): h.name,
    });
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() { _future = f; });
    try {
      await f;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My attendance')),
      body: AsyncBody<_AttendanceData>(
        future: _future,
        onRetry: _refresh,
        skeleton: LoadingSkeleton(
          children: [
            const SkeletonBox(height: 48),
            const SkeletonBox(height: 96, radius: Radii.card),
            for (var i = 0; i < 4; i++) const SkeletonBox(height: 92, radius: Radii.card),
          ],
        ),
        builder: (context, data) {
          final rows = data.rows.where((r) => r.date.year == _month.year && r.date.month == _month.month).toList();
          final monthHolidays = data.holidays.entries
              .where((e) => e.key.year == _month.year && e.key.month == _month.month)
              .toList()
            ..sort((a, b) => b.key.compareTo(a.key));
          final hours = rows.fold<double>(0, (s, r) => s + (r.totalHours ?? 0));
          final late = rows.where((r) => r.late && !r.lateExcused).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(fmtMonth(_month),
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.sm),
                  child: Row(
                    children: [
                      _Summary(
                          icon: Icons.event_available_outlined,
                          color: AppColors.approved,
                          value: '${rows.length}',
                          label: 'Present'),
                      _Summary(icon: Icons.schedule, color: AppColors.red, value: fmtHours(hours), label: 'Worked'),
                      _Summary(icon: Icons.alarm, color: AppColors.pending, value: '$late', label: 'Late'),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                if (rows.isEmpty && monthHolidays.isEmpty)
                  const EmptyState(icon: Icons.event_busy, message: 'No attendance recorded for this month.')
                else ...[
                  for (final r in rows) ...[
                    _AttendanceTile(row: r, holiday: data.holidays[DateTime(r.date.year, r.date.month, r.date.day)]),
                    const SizedBox(height: Space.sm),
                  ],
                  for (final h in monthHolidays.where(
                      (h) => !rows.any((r) => isSameDay(r.date, h.key)))) ...[
                    AppCard(
                      padding: const EdgeInsets.all(Space.md + 2),
                      child: Row(
                        children: [
                          DateBadge(date: h.key, caption: fmtWeekdayShort(h.key)),
                          const SizedBox(width: Space.md + 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.value, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text('Public holiday · ${fmtShortDate(h.key)}',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const Icon(Icons.celebration_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          IconBubble(icon, color: color, size: 36),
          const SizedBox(height: Space.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.row, this.holiday});

  final Attendance row;
  final String? holiday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missingPunch = row.checkIn == null || row.checkOut == null;
    return AppCard(
      padding: const EdgeInsets.all(Space.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBadge(date: row.date, caption: fmtWeekdayShort(row.date)),
          const SizedBox(width: Space.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmtTime(row.checkIn)}  →  ${fmtTime(row.checkOut)}',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('Worked ${fmtHours(row.totalHours)}', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Space.sm),
                // One chip style for every flag on the day.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (row.late)
                      StatusChip(row.lateExcused ? 'APPROVED' : 'PENDING',
                          label: row.lateExcused ? 'Late (excused)' : 'Late ${row.lateMinutes ?? ''}m')
                    else if (missingPunch)
                      const StatusChip('PENDING', label: 'Missing punch')
                    else
                      const StatusChip('PRESENT', label: 'Present'),
                    if ((row.shortHours ?? 0) > 0)
                      StatusChip('REJECTED', label: 'Short ${fmtHours(row.shortHours)}'),
                    if (holiday != null) StatusChip(null, label: holiday),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
