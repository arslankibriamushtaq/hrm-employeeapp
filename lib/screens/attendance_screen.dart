import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class _AttendanceData {
  _AttendanceData(this.rows, this.holidays);

  final List<Attendance> rows;
  final Map<DateTime, String> holidays;
}

/// The employee's own attendance (GET /attendance/me), browsed month by month.
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(fmtMonth(_month),
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        _Summary(value: '${rows.length}', label: 'Present'),
                        _Summary(value: fmtHours(hours), label: 'Worked'),
                        _Summary(value: '$late', label: 'Late'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty && monthHolidays.isEmpty)
                  const EmptyView(icon: Icons.event_busy, message: 'No attendance recorded for this month.')
                else ...[
                  for (final r in rows) ...[
                    _AttendanceTile(row: r, holiday: data.holidays[DateTime(r.date.year, r.date.month, r.date.day)]),
                    const SizedBox(height: 8),
                  ],
                  for (final h in monthHolidays.where(
                      (h) => !rows.any((r) => isSameDay(r.date, h.key)))) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.celebration_outlined),
                        title: Text(h.value),
                        subtitle: Text('Public holiday · ${fmtShortDate(h.key)}'),
                      ),
                    ),
                    const SizedBox(height: 8),
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
  const _Summary({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('${row.date.day}',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
                  Text(fmtShortDate(row.date).split(',').first,
                      style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${fmtTime(row.checkIn)}  →  ${fmtTime(row.checkOut)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text('Worked ${fmtHours(row.totalHours)}',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      if ((row.shortHours ?? 0) > 0)
                        Text('· Short ${fmtHours(row.shortHours)}', style: TextStyle(color: scheme.error)),
                      if (holiday != null) Text('· $holiday', style: TextStyle(color: scheme.tertiary)),
                    ],
                  ),
                ],
              ),
            ),
            if (row.late)
              StatusChip(row.lateExcused ? 'APPROVED' : 'PENDING',
                  label: row.lateExcused ? 'Late (excused)' : 'Late ${row.lateMinutes ?? ''}m')
            else if (missingPunch)
              const StatusChip('PENDING', label: 'Missing punch')
            else
              const StatusChip('PRESENT', label: 'Present'),
          ],
        ),
      ),
    );
  }
}
