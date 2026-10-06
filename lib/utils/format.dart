import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy');
final _shortDate = DateFormat('EEE, d MMM');
final _time = DateFormat('h:mm a');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _month = DateFormat('MMMM yyyy');

String fmtDate(DateTime? d) => d == null ? '—' : _date.format(d);
String fmtShortDate(DateTime? d) => d == null ? '—' : _shortDate.format(d);
String fmtTime(DateTime? d) => d == null ? '—' : _time.format(d);
String fmtDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
String fmtMonth(DateTime d) => _month.format(d);

/// 7.5 -> "7h 30m"
String fmtHours(double? hours) {
  if (hours == null) return '—';
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String fmtDateRange(DateTime start, DateTime end) {
  if (isSameDay(start, end)) return fmtDate(start);
  if (start.year == end.year) {
    return '${DateFormat('d MMM').format(start)} – ${fmtDate(end)}';
  }
  return '${fmtDate(start)} – ${fmtDate(end)}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "NOT_REQUIRED" -> "Not required"
String humanize(String? value) {
  if (value == null || value.isEmpty) return '—';
  final s = value.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}
