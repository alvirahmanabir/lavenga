import '../../core/utils/time_format.dart';
import '../enums.dart';
import '../models/booking.dart';
import '../models/catalogue.dart';

/// Something occupying a space on the calendar.
class BusyInterval {
  const BusyInterval(this.schedule, this.kind);
  final BookingSchedule schedule;

  /// confirmed, pending (unpaid hold / awaiting review) or unavailable (block).
  final SlotState kind;
}

class SlotInfo {
  const SlotInfo(this.start, this.state);
  final DateTime start;
  final SlotState state;
  bool get selectable => state == SlotState.available || state == SlotState.selected;
}

/// Client-side availability checks. These are ADVISORY: real exclusivity must
/// be enforced by transactional backend logic and PostgreSQL exclusion
/// constraints (see docs/CONCURRENCY.md).
abstract final class AvailabilityService {
  static const int stepMinutes = 30;

  /// Returns an error message, or null when [schedule] is valid for [space].
  static String? validateSchedule(
    StudioSpace space,
    BookingSchedule schedule, {
    required DateTime now,
  }) {
    final minutes = schedule.minutes;
    if (!schedule.start.isAfter(now)) return 'Choose a time in the future';
    if (minutes <= 0) return 'End time must be after start time';
    if (minutes % stepMinutes != 0) return 'Durations use ${stepMinutes}-minute steps';
    if (minutes < space.minMinutes) {
      return 'Minimum booking is ${fmtDuration(space.minMinutes)}';
    }
    if (minutes > space.maxMinutes) {
      return 'Maximum booking is ${fmtDuration(space.maxMinutes)}';
    }
    final startLocal = toStudioLocal(schedule.start);
    final endLocal = toStudioLocal(schedule.end);
    final sameDay = startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day;
    final startMin = startLocal.hour * 60 + startLocal.minute;
    final endMin = sameDay
        ? endLocal.hour * 60 + endLocal.minute
        : 24 * 60; // crosses midnight: always outside hours
    if (!space.hours.isOpenOn(startLocal.weekday)) {
      return 'This space is closed on that day';
    }
    if (!sameDay || startMin < space.hours.openMinute || endMin > space.hours.closeMinute) {
      return 'Bookings must fall within ${space.hours.label}';
    }
    return null;
  }

  /// First busy interval that conflicts with [schedule] once the space's
  /// setup/cleanup buffer is applied, or null if free.
  static BusyInterval? firstConflict(
    StudioSpace space,
    BookingSchedule schedule,
    Iterable<BusyInterval> busy,
  ) {
    for (final b in busy) {
      if (schedule.overlaps(b.schedule, bufferMinutes: space.bufferMinutes)) {
        return b;
      }
    }
    return null;
  }

  static bool isFree(
    StudioSpace space,
    BookingSchedule schedule,
    Iterable<BusyInterval> busy,
  ) =>
      firstConflict(space, schedule, busy) == null;

  /// Start-time slots for one studio-local day, in 30-minute steps. A slot is
  /// judged by whether the space's minimum duration fits starting there.
  static List<SlotInfo> startSlots({
    required StudioSpace space,
    required DateTime dayStart,
    required Iterable<BusyInterval> busy,
    required DateTime now,
    DateTime? selectedStart,
  }) {
    final local = toStudioLocal(dayStart);
    if (!space.hours.isOpenOn(local.weekday)) return const [];
    final slots = <SlotInfo>[];
    final lastStart = space.hours.closeMinute - space.minMinutes;
    for (var m = space.hours.openMinute; m <= lastStart; m += stepMinutes) {
      final start = dayStart.add(Duration(minutes: m));
      final probe = BookingSchedule(
        start: start,
        end: start.add(Duration(minutes: space.minMinutes)),
      );
      SlotState state;
      if (!start.isAfter(now)) {
        state = SlotState.past;
      } else {
        final conflict = firstConflict(space, probe, busy);
        state = conflict == null ? SlotState.available : conflict.kind;
      }
      if (selectedStart != null && start == selectedStart && state == SlotState.available) {
        state = SlotState.selected;
      }
      slots.add(SlotInfo(start, state));
    }
    return slots;
  }

  /// Longest bookable duration from [start]: capped by the space maximum,
  /// closing time, and the next busy interval (minus buffer).
  static int maxDurationFrom({
    required StudioSpace space,
    required DateTime start,
    required Iterable<BusyInterval> busy,
  }) {
    final closeAt = studioDayStart(start).add(Duration(minutes: space.hours.closeMinute));
    var limit = closeAt.difference(start).inMinutes;
    if (limit > space.maxMinutes) limit = space.maxMinutes;
    final buffer = Duration(minutes: space.bufferMinutes);
    for (final b in busy) {
      final blockStart = b.schedule.start.subtract(buffer);
      if (!b.schedule.end.add(buffer).isAfter(start)) continue; // already past
      if (blockStart.isAfter(start)) {
        final room = blockStart.difference(start).inMinutes;
        if (room < limit) limit = room;
      } else {
        return 0; // start itself is inside a blocked window
      }
    }
    return (limit ~/ stepMinutes) * stepMinutes;
  }
}
