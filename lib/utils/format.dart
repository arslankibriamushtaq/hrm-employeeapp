import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy');
final _shortDate = DateFormat('EEE, d MMM');
final _time = DateFormat('h:mm a');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _month = DateFormat('MMMM yyyy');
final _monthShort = DateFormat('MMM');
final _weekdayShort = DateFormat('EEE');

String fmtDate(DateTime? d) => d == null ? '—' : _date.format(d);
String fmtShortDate(DateTime? d) => d == null ? '—' : _shortDate.format(d);
String fmtTime(DateTime? d) => d == null ? '—' : _time.format(d);
String fmtDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
String fmtMonth(DateTime d) => _month.format(d);

/// "Sep" / "Tue" for date badges.
String fmtMonthShort(DateTime d) => _monthShort.format(d);
String fmtWeekdayShort(DateTime d) => _weekdayShort.format(d);

/// 7.5 -> "7h 30m"
String fmtHours(double? hours) {
  if (hours == null) return '—';
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Late chip text, reusing [fmtHours]. Null, 0 or negative minutes give plain "Late".
/// 1 -> "Late 1m", 45 -> "Late 45m", 59 -> "Late 59m", 60 -> "Late 1h", 61 -> "Late 1h 1m",
/// 93 -> "Late 1h 33m", 120 -> "Late 2h", 150 -> "Late 2h 30m", 605 -> "Late 10h 5m".
String fmtLate(int? minutes) {
  final m = minutes ?? 0;
  return m > 0 ? 'Late ${fmtHours(m / 60)}' : 'Late';
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
