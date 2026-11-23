import '../../domain/models/booking.dart';

/// All studios use Asia/Dhaka (UTC+6, no DST) for now. Storage is UTC;
/// these helpers convert to studio-local wall time for display and rules.
const Duration kStudioOffset = Duration(hours: 6);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Returns a DateTime whose fields are the studio-local wall clock.
DateTime toStudioLocal(DateTime utc) => utc.toUtc().add(kStudioOffset);

/// Builds a UTC instant from studio-local date parts.
DateTime fromStudioLocal(int year, int month, int day, [int minuteOfDay = 0]) =>
    DateTime.utc(year, month, day).add(Duration(minutes: minuteOfDay)).subtract(kStudioOffset);

/// Midnight of the studio-local day containing [utc], as a UTC instant.
DateTime studioDayStart(DateTime utc) {
  final l = toStudioLocal(utc);
  return fromStudioLocal(l.year, l.month, l.day);
}

int studioMinuteOfDay(DateTime utc) {
  final l = toStudioLocal(utc);
  return l.hour * 60 + l.minute;
}

String fmtDate(DateTime utc) {
  final l = toStudioLocal(utc);
  return '${_weekdays[l.weekday - 1]}, ${l.day} ${_months[l.month - 1]}';
}

String fmtDateLong(DateTime utc) {
  final l = toStudioLocal(utc);
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

String fmtTime(DateTime utc) {
  final l = toStudioLocal(utc);
  final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final period = l.hour >= 12 ? 'PM' : 'AM';
  return '$h12:${l.minute.toString().padLeft(2, '0')} $period';
}

String fmtMinuteOfDay(int minute) {
  final h = minute ~/ 60;
  final m = minute % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h >= 12 && h < 24 ? 'PM' : 'AM'}';
}

String fmtDateTime(DateTime utc) => '${fmtDateLong(utc)}, ${fmtTime(utc)}';

String fmtRange(BookingSchedule s) =>
    '${fmtDate(s.start)} · ${fmtTime(s.start)} – ${fmtTime(s.end)}';

String fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '${h}h ${m}m';
}

String fmtCountdown(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// "5 min ago", "2 h ago", "3 d ago".
String fmtAgo(DateTime utc, DateTime now) {
  final d = now.difference(utc);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
