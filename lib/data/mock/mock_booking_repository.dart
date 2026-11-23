import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../core/utils/time_format.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/services/availability_service.dart';
import '../../domain/services/payment_calculator.dart';
import '../../domain/services/policies.dart';
import '../../domain/services/pricing_service.dart';
import 'mock_context.dart';

class MockBookingRepository extends MockRepo implements BookingRepository {
  MockBookingRepository(super.ctx);

  List<QuoteInput> _inputs(List<CartLine> lines) {
    final inputs = <QuoteInput>[];
    for (final line in lines) {
      inputs.add(QuoteInput(
        itemId: line.id,
        space: spaceById(line.spaceId),
        schedule: line.schedule,
      ));
    }
    return inputs;
  }

  @override
  Future<QuoteResult> quote({
    required String customerId,
    required List<CartLine> lines,
    String? couponCode,
  }) async {
    final customer = userById(customerId);
    return PricingService.quote(
      items: _inputs(lines),
      settings: db.settings,
      customerId: customerId,
      now: now,
      customerDiscountBp: customer.customer?.discountBp ?? 0,
      couponCode: couponCode,
      coupons: db.coupons,
      discounts: db.discounts,
    );
  }

  /// Validates every line, then checks lines against each other and against
  /// the calendar. Throws on the first problem.
  void _validateLines(List<CartLine> lines, {String? ignoreBookingId}) {
    sweepHolds();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final space = spaceById(line.spaceId);
      if (!space.isBookable) {
        throw ValidationFailure('${space.name} is not available for booking right now');
      }
      final error = AvailabilityService.validateSchedule(space, line.schedule, now: now);
      if (error != null) throw ValidationFailure('${space.name}: $error');

      final busy = busyFor(space.id).where((b) => true).toList();
      if (ignoreBookingId != null) {
        // Rebuild busy without the booking being modified.
        busy
          ..clear()
          ..addAll(_busyExcluding(space.id, ignoreBookingId));
      }
      final conflict = AvailabilityService.firstConflict(space, line.schedule, busy);
      if (conflict != null) {
        throw SlotConflict(
          '${space.name} is not available ${fmtRange(line.schedule)}. '
          'Please choose another time.',
        );
      }
      for (var j = 0; j < i; j++) {
        final other = lines[j];
        if (other.spaceId == line.spaceId &&
            line.schedule.overlaps(other.schedule, bufferMinutes: space.bufferMinutes)) {
          throw SlotConflict(
            '${space.name} appears twice with overlapping or touching times in your cart.',
          );
        }
      }
    }
  }

  List<BusyInterval> _busyExcluding(String spaceId, String bookingId) {
    final busy = <BusyInterval>[];
    for (final b in db.bookings) {
      if (b.id == bookingId || !b.status.occupiesSlot) continue;
      final kind =
          b.status == BookingStatus.pendingReview ? SlotState.pending : SlotState.confirmed;
      for (final item in b.items) {
        if (item.spaceId == spaceId) busy.add(BusyInterval(item.schedule, kind));
      }
    }
    for (final block in db.blocks) {
      if (block.spaceId == spaceId) {
        busy.add(BusyInterval(
          BookingSchedule(start: block.start, end: block.end),
          SlotState.unavailable,
        ));
      }
    }
    return busy;
  }

  @override
  Future<Booking> createOrder({
    required AppUser customer,
    required List<CartLine> lines,
    String? couponCode,
    String notes = '',
  }) async {
    await wait(const Duration(milliseconds: 300));
    final user = fresh(customer);
    if (user.isRestricted) throw const Forbidden('restricted account');
    if (!user.verified) {
      throw const ValidationFailure('Verify your account before booking');
    }
    if (lines.isEmpty) throw const ValidationFailure('Your cart is empty');
    _validateLines(lines);

    final result = await quote(customerId: user.id, lines: lines, couponCode: couponCode);
    if (couponCode != null &&
        couponCode.trim().isNotEmpty &&
        !(result.coupon?.valid ?? false)) {
      throw ValidationFailure(result.coupon?.message ?? 'Coupon is not valid');
    }

    final bookingId = db.newId('bk');
    final items = <BookingItem>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final space = spaceById(line.spaceId);
      final studio = db.studios.firstWhere((s) => s.id == space.studioId);
      items.add(BookingItem(
        id: '${bookingId}_i$i',
        spaceId: space.id,
        spaceCode: space.code,
        spaceName: space.name,
        studioId: space.studioId,
        studioName: studio.name,
        schedule: line.schedule,
        hourlyRate: space.hourlyRate,
        spaceDiscountBp: space.discountBp,
        notes: line.notes,
        imageUrl: space.images.isEmpty ? null : space.images.first,
      ));
    }
    // Re-key pricing lines to the persisted item ids.
    final snapshot = BookingPricingSnapshot(
      lines: [
        for (var i = 0; i < result.pricing.lines.length; i++)
          PricingLine(
            itemId: items[i].id,
            label: result.pricing.lines[i].label,
            minutes: result.pricing.lines[i].minutes,
            gross: result.pricing.lines[i].gross,
            spaceDiscount: result.pricing.lines[i].spaceDiscount,
          ),
      ],
      subtotal: result.pricing.subtotal,
      spaceDiscount: result.pricing.spaceDiscount,
      customerDiscount: result.pricing.customerDiscount,
      couponDiscount: result.pricing.couponDiscount,
      couponCode: result.pricing.couponCode,
      fees: result.pricing.fees,
      total: result.pricing.total,
      advanceRequired: result.pricing.advanceRequired,
    );

    // Record the coupon redemption with the order.
    if (result.coupon?.valid ?? false) {
      final coupon = result.coupon!.coupon!;
      final redemptions = {...coupon.redemptions};
      redemptions[user.id] = (redemptions[user.id] ?? 0) + 1;
      final ci = db.coupons.indexWhere((c) => c.id == coupon.id);
      db.coupons[ci] = coupon.copyWith(redemptions: redemptions);
    }

    final reference = 'LV-${(2610 + db.bookings.length + 1)}-${(100 + (db.counter % 900))}';
    final booking = Booking(
      id: bookingId,
      reference: reference,
      customerId: user.id,
      customerName: user.fullName,
      items: items,
      pricing: snapshot,
      status: BookingStatus.pendingReview,
      paymentStatus: PaymentStatus.unpaid,
      notes: notes,
      holdExpiresAt: now.add(Duration(minutes: db.settings.holdMinutes)),
      createdAt: now,
      updatedAt: now,
      timeline: [
        TimelineEvent(
          at: now,
          title: 'Order placed',
          actor: user.fullName,
          note: 'Slots held for ${db.settings.holdMinutes} minutes while you pay.',
        ),
      ],
    );
    db.bookings.add(booking);
    commit();
    return booking;
  }

  @override
  Future<Booking> getBooking(String id) async {
    sweepHolds();
    return bookingById(id);
  }

  @override
  Future<List<Booking>> listForCustomer(String customerId) async {
    sweepHolds();
    return db.bookings.where((b) => b.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Booking>> search(BookingFilter f, {required AppUser actor}) async {
    sweepHolds();
    final user = fresh(actor);
    final q = f.text.trim().toLowerCase();
    final list = db.bookings.where((b) {
      if (!PermissionPolicy.canSeeBooking(user, b)) return false;
      if (f.customerId != null && b.customerId != f.customerId) return false;
      if (f.statuses.isNotEmpty && !f.statuses.contains(b.status)) return false;
      if (f.paymentStatuses.isNotEmpty && !f.paymentStatuses.contains(b.paymentStatus)) {
        return false;
      }
      if (f.from != null && b.lastEnd.isBefore(f.from!)) return false;
      if (f.to != null && b.firstStart.isAfter(f.to!)) return false;
      if (q.isNotEmpty) {
        final hay = [
          b.id,
          b.reference,
          b.customerName,
          for (final i in b.items) ...[i.spaceCode, i.spaceName, i.studioName],
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Booking> cancelByCustomer(String bookingId, {required AppUser actor}) async {
    await wait();
    sweepHolds();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (b.customerId != user.id) throw const Forbidden('not your booking');
    if (!CancellationPolicy.canCustomerCancel(b)) {
      throw const ValidationFailure(
        'This booking is already confirmed. Contact support to make changes.',
      );
    }
    final updated = b.copyWith(
      status: BookingStatus.cancelled,
      clearHold: true,
      cancelReason: 'Cancelled by customer before confirmation',
      updatedAt: now,
      timeline: [
        ...b.timeline,
        TimelineEvent(at: now, title: 'Cancelled', actor: user.fullName, note: 'Cancelled before confirmation'),
      ],
    );
    putBooking(updated);
    final paid = PaymentCalculator.verifiedPaid(paymentsOf(b.id));
    notifyStaff(b.studioIds, 'Booking cancelled', '${b.reference} was cancelled by the customer.', 'booking',
        refId: b.id, needs: StaffPermission.confirmBookings);
    if (paid.isPositive) {
      notifyUser(user.id, 'Booking cancelled',
          'You can request a refund for ${paid.format()} from the booking page.', 'booking',
          refId: b.id);
    }
    commit();
    return updated;
  }

  @override
  Future<Booking> updateStatus(String bookingId, BookingStatus to,
      {required AppUser actor, String? reason}) async {
    await wait();
    sweepHolds();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (user.isCustomer || !PermissionPolicy.canSeeBooking(user, b)) {
      throw const Forbidden('booking');
    }
    final needsCancelRight = to == BookingStatus.cancelled;
    requirePermission(
      user,
      needsCancelRight ? StaffPermission.cancelBookings : StaffPermission.confirmBookings,
    );
    if (!BookingTransitions.allowed(b.status, to)) {
      throw ValidationFailure(
        'A ${b.status.label.toLowerCase()} booking cannot become ${to.label.toLowerCase()}.',
      );
    }
    if ((to == BookingStatus.cancelled || to == BookingStatus.rejected) &&
        (reason == null || reason.trim().isEmpty)) {
      throw const ValidationFailure('A reason is required', field: 'reason');
    }
    if (to == BookingStatus.confirmed) {
      final paid = PaymentCalculator.verifiedPaid(paymentsOf(b.id));
      if (!paid.isPositive) {
        throw const ValidationFailure(
          'No verified payment yet. Confirm once the advance is received.',
        );
      }
    }
    final updated = b.copyWith(
      status: to,
      clearHold: true,
      cancelReason: (to == BookingStatus.cancelled || to == BookingStatus.rejected)
          ? reason!.trim()
          : null,
      updatedAt: now,
      timeline: [
        ...b.timeline,
        TimelineEvent(at: now, title: to.label, actor: user.fullName, note: reason?.trim()),
      ],
    );
    putBooking(updated);
    audit(user, 'Booking ${to.label.toLowerCase()}', b.reference,
        detail: reason, sensitive: to == BookingStatus.cancelled);
    notifyUser(
      b.customerId,
      'Booking ${to.label.toLowerCase()}',
      to == BookingStatus.confirmed
          ? '${b.reference} is confirmed. See you at the studio.'
          : '${b.reference} is now ${to.label.toLowerCase()}.',
      'booking',
      refId: b.id,
    );
    commit();
    return updated;
  }

  @override
  Future<Booking> addInternalNote(String bookingId, String text, {required AppUser actor}) async {
    await wait();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (user.isCustomer || !PermissionPolicy.canSeeBooking(user, b)) {
      throw const Forbidden('booking');
    }
    if (text.trim().isEmpty) throw const ValidationFailure('Write a note first');
    final updated = b.copyWith(
      internalNotes: [
        ...b.internalNotes,
        InternalNote(id: db.newId('note'), authorName: user.fullName, text: text.trim(), at: now),
      ],
      updatedAt: now,
    );
    putBooking(updated);
    commit();
    return updated;
  }

  @override
  Future<Booking> rescheduleItem(String bookingId, String itemId, BookingSchedule schedule,
      {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    final b = bookingById(bookingId);
    if (b.status.isClosed) {
      throw const ValidationFailure('Closed bookings cannot be modified');
    }
    final index = b.items.indexWhere((i) => i.id == itemId);
    if (index < 0) throw const NotFoundFailure('booking item');
    final item = b.items[index];
    final space = spaceById(item.spaceId);
    sweepHolds();
    final error = AvailabilityService.validateSchedule(space, schedule, now: now);
    if (error != null) throw ValidationFailure(error);
    final conflict = AvailabilityService.firstConflict(
      space,
      schedule,
      _busyExcluding(space.id, b.id),
    );
    if (conflict != null) {
      throw SlotConflict('${space.name} is not free at that time.');
    }

    // Reprice the item at its original (snapshotted) rate; keep other
    // discounts exactly as agreed at checkout.
    final gross = PricingService.lineGross(item.hourlyRate, schedule.minutes);
    final newLines = [
      for (final l in b.pricing.lines)
        if (l.itemId == itemId)
          PricingLine(
            itemId: l.itemId,
            label: l.label,
            minutes: schedule.minutes,
            gross: gross,
            spaceDiscount: gross.percent(item.spaceDiscountBp),
          )
        else
          l,
    ];
    final p = b.pricing;
    final subtotal = newLines.fold(Money.zero, (s, l) => s + l.gross);
    final spaceDiscount = newLines.fold(Money.zero, (s, l) => s + l.spaceDiscount);
    final net = (subtotal - spaceDiscount - p.customerDiscount - p.couponDiscount)
        .clampMin(Money.zero);
    final fees = net.percent(db.settings.vatBp);
    final total = net + fees;
    final newPricing = BookingPricingSnapshot(
      lines: newLines,
      subtotal: subtotal,
      spaceDiscount: spaceDiscount,
      customerDiscount: p.customerDiscount,
      couponDiscount: p.couponDiscount,
      couponCode: p.couponCode,
      fees: fees,
      total: total,
      advanceRequired: PaymentCalculator.advanceAmount(total, db.settings.advanceBp),
    );
    final items = [...b.items]..[index] = item.copyWith(schedule: schedule);
    putBooking(b.copyWith(
      items: items,
      pricing: newPricing,
      updatedAt: now,
      timeline: [
        ...b.timeline,
        TimelineEvent(
          at: now,
          title: 'Rescheduled',
          actor: actor.fullName,
          note: '${item.spaceName}: ${fmtRange(schedule)}',
        ),
      ],
    ));
    recomputePayment(b.id);
    audit(actor, 'Modified booking', b.reference,
        detail: '${item.spaceName} → ${fmtRange(schedule)}', sensitive: true);
    notifyUser(b.customerId, 'Booking updated',
        '${b.reference}: ${item.spaceName} moved to ${fmtRange(schedule)}.', 'booking',
        refId: b.id);
    commit();
    return bookingById(b.id);
  }

  @override
  Future<int> expireHolds() async {
    final n = sweepHolds();
    if (n > 0) commit();
    return n;
  }
}
