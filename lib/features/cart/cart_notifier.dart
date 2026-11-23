import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/services/availability_service.dart';
import '../../domain/services/pricing_service.dart';
import '../../core/clock/clock.dart';

/// Multi-space cart. Every line has its own date, time and notes. Lines are
/// revalidated by the repository at checkout; the checks here only prevent
/// obviously invalid entries (past times, outside hours, overlapping lines).
class CartNotifier extends Notifier<List<CartLine>> {
  String? _userId;

  @override
  List<CartLine> build() {
    _userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    if (_userId == null) return const [];
    final raw = ref.read(localStoreProvider).read('cart_$_userId');
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          CartLine(
            id: e['id'] as String,
            spaceId: e['space_id'] as String,
            notes: e['notes'] as String? ?? '',
            schedule: BookingSchedule(
              start: DateTime.parse(e['start'] as String).toUtc(),
              end: DateTime.parse(e['end'] as String).toUtc(),
            ),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _save() {
    final id = _userId;
    if (id == null) return;
    ref.read(localStoreProvider).write(
          'cart_$id',
          jsonEncode([
            for (final l in state)
              {
                'id': l.id,
                'space_id': l.spaceId,
                'notes': l.notes,
                'start': l.schedule.start.toIso8601String(),
                'end': l.schedule.end.toIso8601String(),
              },
          ]),
        );
  }

  /// Adds or replaces a line. Returns an error message, or null on success.
  String? add(CartLine line, StudioSpace space) {
    final now = ref.read(clockProvider).now();
    final error = AvailabilityService.validateSchedule(space, line.schedule, now: now);
    if (error != null) return error;
    for (final other in state) {
      if (other.id == line.id) continue;
      if (other.spaceId == line.spaceId &&
          line.schedule.overlaps(other.schedule, bufferMinutes: space.bufferMinutes)) {
        return 'You already have ${space.name} in your cart at an overlapping time.';
      }
    }
    state = [
      for (final l in state)
        if (l.id != line.id) l,
      line,
    ];
    _save();
    return null;
  }

  void remove(String lineId) {
    state = [for (final l in state) if (l.id != lineId) l];
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  String newLineId() => 'line_${DateTime.now().microsecondsSinceEpoch}';
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).length);

/// Indicative quote for the current cart. Family key is the coupon code
/// (null or empty = none). Never a booking guarantee.
final cartQuoteProvider = FutureProvider.autoDispose.family<QuoteResult, String>((ref, coupon) {
  ref.watch(dbVersionProvider);
  final lines = ref.watch(cartProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(bookingRepositoryProvider).quote(
        customerId: user.id,
        lines: lines,
        couponCode: coupon.isEmpty ? null : coupon,
      );
});
