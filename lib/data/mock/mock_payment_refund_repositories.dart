import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/services/payment_calculator.dart';
import '../../domain/services/policies.dart';
import 'mock_context.dart';

class MockPaymentRepository extends MockRepo implements PaymentRepository {
  MockPaymentRepository(super.ctx);

  Payment _payment(String id) {
    for (final p in db.payments) {
      if (p.id == id) return p;
    }
    throw const NotFoundFailure('payment');
  }

  void _put(Payment p) {
    db.payments[db.payments.indexWhere((x) => x.id == p.id)] = p;
  }

  PaymentTransaction _newTransaction(Payment p, PaymentMethod method) {
    db.counter++;
    return PaymentTransaction(
      id: db.newId('tx'),
      paymentId: p.id,
      amount: p.amount,
      method: method,
      status: TransactionStatus.pendingVerification,
      gatewayRef: 'SSL${db.counter * 37 + 100000}',
      at: now,
    );
  }

  @override
  Future<Payment> startPayment({
    required String bookingId,
    required PaymentKind kind,
    required PaymentMethod method,
    required AppUser actor,
  }) async {
    await wait();
    sweepHolds();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (b.customerId != user.id) throw const Forbidden('not your booking');
    if (b.status == BookingStatus.expired) throw const HoldExpired();
    if (b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected) {
      throw const ValidationFailure('This booking is closed and cannot be paid');
    }
    final pays = paymentsOf(bookingId);
    final due = PaymentCalculator.remainingDue(b.total, pays);
    if (!due.isPositive) throw const ValidationFailure('Nothing is due on this booking');
    if (pays.any((p) => p.status == TransactionStatus.pendingVerification)) {
      throw const PaymentPending();
    }
    final amount = kind == PaymentKind.advance
        ? b.pricing.advanceRequired.clampMax(due)
        : due; // full and balance both settle what remains
    final payment = Payment(
      id: db.newId('pay'),
      bookingId: bookingId,
      bookingRef: b.reference,
      customerId: user.id,
      kind: kind,
      amount: amount,
      createdAt: now,
    );
    db.payments.add(payment.copyWith(transactions: [_newTransaction(payment, method)]));
    recomputePayment(bookingId);
    commit();
    return _payment(payment.id);
  }

  @override
  Future<Payment> simulateGateway(String paymentId, GatewayOutcome outcome) async {
    await wait(const Duration(milliseconds: 900));
    final payment = _payment(paymentId);
    final last = payment.latest;
    if (last == null || last.status != TransactionStatus.pendingVerification) {
      return payment;
    }
    final status = switch (outcome) {
      GatewayOutcome.success => TransactionStatus.verified,
      GatewayOutcome.failure => TransactionStatus.failed,
      GatewayOutcome.cancelled => TransactionStatus.cancelled,
      GatewayOutcome.timeout => TransactionStatus.timedOut,
    };
    final updatedTx = PaymentTransaction(
      id: last.id,
      paymentId: last.paymentId,
      amount: last.amount,
      method: last.method,
      status: status,
      gatewayRef: last.gatewayRef,
      at: now,
      failureReason: switch (outcome) {
        GatewayOutcome.failure => 'The payment was declined by the provider',
        GatewayOutcome.cancelled => 'You cancelled the payment',
        GatewayOutcome.timeout => 'The payment session timed out',
        GatewayOutcome.success => null,
      },
    );
    final txs = [...payment.transactions]..[payment.transactions.length - 1] = updatedTx;
    _put(payment.copyWith(transactions: txs));

    final b = bookingById(payment.bookingId);
    if (status == TransactionStatus.verified) {
      putBooking(b.copyWith(
        clearHold: true,
        timeline: [
          ...b.timeline,
          TimelineEvent(
            at: now,
            title: 'Payment received',
            actor: 'Payment gateway',
            note: '${payment.amount.format()} via ${last.method.label}',
          ),
        ],
      ));
      notifyUser(b.customerId, 'Payment received',
          'We received ${payment.amount.format()} for ${b.reference}.', 'payment',
          refId: b.id);
      notifyStaff(b.studioIds, 'New payment', '${b.reference}: ${payment.amount.format()} received.',
          'payment', refId: b.id, needs: StaffPermission.viewPayments);
    }
    recomputePayment(payment.bookingId);
    commit();
    return _payment(paymentId);
  }

  @override
  Future<Payment> retry(String paymentId, PaymentMethod method) async {
    await wait();
    sweepHolds();
    final payment = _payment(paymentId);
    final b = bookingById(payment.bookingId);
    if (b.status == BookingStatus.expired) throw const HoldExpired();
    if (b.status.isClosed) throw const ValidationFailure('This booking is closed');
    final status = payment.status;
    if (status == TransactionStatus.verified) {
      throw const ValidationFailure('This payment already succeeded');
    }
    if (status == TransactionStatus.pendingVerification) throw const PaymentPending();
    _put(payment.copyWith(transactions: [...payment.transactions, _newTransaction(payment, method)]));
    recomputePayment(payment.bookingId);
    commit();
    return _payment(paymentId);
  }

  @override
  Future<Payment> getPayment(String id) async => _payment(id);

  @override
  Future<List<Payment>> listForBooking(String bookingId) async =>
      paymentsOf(bookingId)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Payment>> listForCustomer(String customerId) async =>
      db.payments.where((p) => p.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Payment>> listForStaff({required AppUser actor, String query = ''}) async {
    final user = fresh(actor);
    requirePermission(user, StaffPermission.viewPayments);
    final q = query.trim().toLowerCase();
    return db.payments.where((p) {
      final b = bookingById(p.bookingId);
      if (!PermissionPolicy.canSeeBooking(user, b)) return false;
      if (q.isEmpty) return true;
      return p.bookingRef.toLowerCase().contains(q) ||
          b.customerName.toLowerCase().contains(q) ||
          (p.latest?.gatewayRef.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Payment> reconcile(String paymentId,
      {required bool verified, required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    final payment = _payment(paymentId);
    final last = payment.latest;
    if (last == null) throw const ValidationFailure('No transaction to reconcile');
    final status = verified ? TransactionStatus.verified : TransactionStatus.failed;
    final txs = [...payment.transactions]..[payment.transactions.length - 1] = PaymentTransaction(
        id: last.id,
        paymentId: last.paymentId,
        amount: last.amount,
        method: last.method,
        status: status,
        gatewayRef: last.gatewayRef,
        at: now,
        failureReason: verified ? null : 'Marked failed during reconciliation',
      );
    _put(payment.copyWith(transactions: txs));
    recomputePayment(payment.bookingId);
    audit(actor, verified ? 'Reconciled payment as verified' : 'Reconciled payment as failed',
        payment.bookingRef, detail: payment.amount.format(), sensitive: true);
    commit();
    return _payment(paymentId);
  }
}

class MockRefundRepository extends MockRepo implements RefundRepository {
  MockRefundRepository(super.ctx);

  RefundRequest _refund(String id) {
    for (final r in db.refunds) {
      if (r.id == id) return r;
    }
    throw const NotFoundFailure('refund request');
  }

  void _put(RefundRequest r) {
    db.refunds[db.refunds.indexWhere((x) => x.id == r.id)] = r;
  }

  @override
  Future<Money> refundableAmount(String bookingId) async {
    final net = PaymentCalculator.netPaid(paymentsOf(bookingId), refundedOf(bookingId));
    final open = db.refunds
        .where((r) =>
            r.bookingId == bookingId &&
            (r.status == RefundStatus.requested ||
                r.status == RefundStatus.underManagerReview ||
                r.status == RefundStatus.forwardedToAdmin ||
                r.status == RefundStatus.approved ||
                r.status == RefundStatus.processing))
        .fold(Money.zero, (sum, r) => sum + (r.approved ?? r.requested));
    return (net - open).clampMin(Money.zero);
  }

  @override
  Future<RefundRequest> request({
    required String bookingId,
    required Money amount,
    required String reason,
    required AppUser actor,
  }) async {
    await wait();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (b.customerId != user.id) throw const Forbidden('not your booking');
    final refundable = await refundableAmount(bookingId);
    if (!CancellationPolicy.canRequestRefund(
      booking: b,
      netPaid: PaymentCalculator.netPaid(paymentsOf(bookingId), refundedOf(bookingId)),
      alreadyRequestedOpen: (PaymentCalculator.netPaid(paymentsOf(bookingId), refundedOf(bookingId)) - refundable),
    )) {
      throw const ValidationFailure('This booking is not eligible for a refund request');
    }
    if (reason.trim().length < 5) {
      throw const ValidationFailure('Tell us why you are requesting a refund', field: 'reason');
    }
    if (!amount.isPositive || amount > refundable) {
      throw ValidationFailure(
        'You can request up to ${refundable.format()}',
        field: 'amount',
      );
    }
    final id = db.newId('rf');
    final refund = RefundRequest(
      id: id,
      bookingId: b.id,
      bookingRef: b.reference,
      customerId: user.id,
      customerName: user.fullName,
      reason: reason.trim(),
      requested: amount,
      status: RefundStatus.requested,
      createdAt: now,
      updatedAt: now,
      timeline: [
        TimelineEvent(at: now, title: 'Refund requested', actor: user.fullName, note: reason.trim()),
      ],
    );
    db.refunds.add(refund);
    notifyStaff(b.studioIds, 'Refund requested',
        '${b.reference}: ${amount.format()} requested by ${user.fullName}.', 'refund',
        refId: id, needs: StaffPermission.handleRefunds);
    commit();
    return refund;
  }

  @override
  Future<RefundRequest> getRefund(String id) async => _refund(id);

  @override
  Future<List<RefundRequest>> listForCustomer(String customerId) async =>
      db.refunds.where((r) => r.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<RefundRequest>> listForStaff({required AppUser actor}) async {
    final user = fresh(actor);
    if (user.isCustomer) throw const Forbidden('refunds');
    if (user.isManager) requirePermission(user, StaffPermission.handleRefunds);
    return db.refunds.where((r) {
      if (user.isAdmin) return true;
      return PermissionPolicy.canSeeBooking(user, bookingById(r.bookingId));
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<RefundRequest> perform(
    String refundId,
    RefundAction action, {
    required AppUser actor,
    String? note,
    String? customerNote,
    Money? approvedAmount,
  }) async {
    await wait();
    final user = fresh(actor);
    final refund = _refund(refundId);
    final booking = bookingById(refund.bookingId);

    if (user.isManager) {
      requirePermission(user, StaffPermission.handleRefunds);
      if (!PermissionPolicy.canSeeBooking(user, booking)) throw const Forbidden('outside your studios');
    }
    if (!RefundWorkflow.roleMayPerform(user.role, action)) throw Forbidden(action.name);
    final next = RefundWorkflow.next(refund.status, action);
    if (next == null) {
      throw ValidationFailure(
        'This request is ${refund.status.label.toLowerCase()} and cannot do that now.',
      );
    }
    final needsNote = action == RefundAction.rejectByManager || action == RefundAction.rejectByAdmin;
    if (needsNote && (note == null || note.trim().isEmpty)) {
      throw const ValidationFailure('A reason is required to reject', field: 'note');
    }

    var updated = refund.copyWith(status: next, updatedAt: now);
    final title = switch (action) {
      RefundAction.startReview => 'Review started',
      RefundAction.forward => 'Forwarded to administrator',
      RefundAction.rejectByManager => 'Rejected by manager',
      RefundAction.approve => 'Approved',
      RefundAction.rejectByAdmin => 'Rejected by administrator',
      RefundAction.initiate => 'Refund initiated',
      RefundAction.markRefunded => 'Refund completed',
      RefundAction.markFailed => 'Refund failed',
    };
    final events = [
      ...refund.timeline,
      TimelineEvent(at: now, title: title, actor: user.fullName, note: note?.trim()),
    ];
    updated = updated.copyWith(timeline: events);

    if (user.isManager && note != null && note.trim().isNotEmpty) {
      updated = updated.copyWith(managerNote: note.trim());
    }
    if (user.isAdmin && note != null && note.trim().isNotEmpty) {
      updated = updated.copyWith(adminNote: note.trim());
    }
    if (customerNote != null && customerNote.trim().isNotEmpty) {
      updated = updated.copyWith(customerNote: customerNote.trim());
    }
    if (action == RefundAction.rejectByManager || action == RefundAction.rejectByAdmin) {
      updated = updated.copyWith(customerNote: customerNote?.trim().isNotEmpty == true
          ? customerNote!.trim()
          : note!.trim());
    }
    if (action == RefundAction.approve) {
      final amount = approvedAmount ?? refund.requested;
      if (!amount.isPositive || amount > refund.requested) {
        throw const ValidationFailure('Approved amount must be above zero and within the request');
      }
      updated = updated.copyWith(approved: amount);
    }

    if (action == RefundAction.initiate || action == RefundAction.markRefunded) {
      final amount = updated.approved ?? updated.requested;
      final tx = RefundTransaction(
        id: db.newId('rtx'),
        refundId: refund.id,
        amount: amount,
        status: action == RefundAction.markRefunded
            ? TransactionStatus.verified
            : TransactionStatus.pendingVerification,
        gatewayRef: 'RFD${db.counter * 53 + 200000}',
        at: now,
      );
      updated = updated.copyWith(transactions: [...updated.transactions, tx]);
    }

    _put(updated);

    // The mock gateway completes an initiated refund immediately. The real
    // flow waits for the provider callback and verifies it server-side.
    if (action == RefundAction.initiate) {
      final tx = updated.transactions.last;
      final doneTx = RefundTransaction(
        id: tx.id,
        refundId: tx.refundId,
        amount: tx.amount,
        status: TransactionStatus.verified,
        gatewayRef: tx.gatewayRef,
        at: now,
      );
      final txs = [...updated.transactions]..[updated.transactions.length - 1] = doneTx;
      updated = updated.copyWith(
        status: RefundStatus.refunded,
        transactions: txs,
        customerNote: updated.customerNote ?? 'Refunded to your original payment method.',
        timeline: [
          ...updated.timeline,
          TimelineEvent(at: now, title: 'Refund completed', actor: 'Payment gateway'),
        ],
      );
      _put(updated);
    }

    recomputePayment(refund.bookingId);
    if (action == RefundAction.approve ||
        action == RefundAction.initiate ||
        action == RefundAction.rejectByAdmin ||
        action == RefundAction.rejectByManager) {
      audit(user, title, booking.reference, detail: note, sensitive: true);
    }
    notifyUser(
      refund.customerId,
      'Refund update',
      'Your refund request for ${booking.reference} is now ${updated.status.label.toLowerCase()}.',
      'refund',
      refId: refund.id,
    );
    if (action == RefundAction.forward) {
      // Empty studio set: only administrators are notified.
      notifyStaff(const <String>{}, 'Refund awaiting approval',
          '${booking.reference} was forwarded by ${user.fullName}.', 'refund',
          refId: refund.id);
    }
    commit();
    return _refund(refundId);
  }
}

class MockDiscountRepository extends MockRepo implements DiscountRepository {
  MockDiscountRepository(super.ctx);

  @override
  Future<List<Discount>> listDiscounts() async => List.of(db.discounts);

  @override
  Future<List<Coupon>> listCoupons() async => List.of(db.coupons);

  @override
  Future<Discount> saveDiscount(Discount discount, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (discount.name.trim().isEmpty) throw const ValidationFailure('Give the discount a name');
    if (discount.value <= 0) throw const ValidationFailure('Value must be above zero');
    if (discount.kind == DiscountKind.percentage && discount.value > 10000) {
      throw const ValidationFailure('A percentage cannot exceed 100%');
    }
    if (!discount.endsAt.isAfter(discount.startsAt)) {
      throw const ValidationFailure('End date must be after the start date');
    }
    final i = db.discounts.indexWhere((d) => d.id == discount.id);
    final saved = i < 0
        ? Discount(
            id: db.newId('d'),
            name: discount.name.trim(),
            kind: discount.kind,
            value: discount.value,
            scope: discount.scope,
            targetIds: discount.targetIds,
            minBooking: discount.minBooking,
            maxDiscount: discount.maxDiscount,
            startsAt: discount.startsAt,
            endsAt: discount.endsAt,
            active: discount.active,
          )
        : discount;
    if (i < 0) {
      db.discounts.add(saved);
    } else {
      db.discounts[i] = saved;
    }
    audit(actor, i < 0 ? 'Created discount' : 'Updated discount', saved.name);
    commit();
    return saved;
  }

  @override
  Future<Coupon> saveCoupon(Coupon coupon, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    final code = coupon.code.trim().toUpperCase();
    if (code.length < 3) throw const ValidationFailure('Codes need at least 3 characters');
    if (!db.discounts.any((d) => d.id == coupon.discountId)) {
      throw const ValidationFailure('Choose a discount for this code');
    }
    if (db.coupons.any((c) => c.id != coupon.id && c.code.toUpperCase() == code)) {
      throw const ValidationFailure('That code already exists', field: 'code');
    }
    final i = db.coupons.indexWhere((c) => c.id == coupon.id);
    final saved = i < 0
        ? Coupon(
            id: db.newId('cp'),
            code: code,
            discountId: coupon.discountId,
            usageLimit: coupon.usageLimit,
            perCustomerLimit: coupon.perCustomerLimit,
            active: coupon.active,
          )
        : coupon.copyWith(code: code);
    if (i < 0) {
      db.coupons.add(saved);
    } else {
      db.coupons[i] = saved;
    }
    audit(actor, i < 0 ? 'Created coupon' : 'Updated coupon', code);
    commit();
    return saved;
  }

  @override
  Future<List<OfferView>> activeOffers() async {
    final out = <OfferView>[];
    for (final d in db.discounts) {
      if (!d.active || now.isBefore(d.startsAt) || now.isAfter(d.endsAt)) continue;
      if (d.scope == DiscountScope.customer) continue;
      Coupon? coupon;
      for (final c in db.coupons) {
        if (c.discountId == d.id && c.active) {
          coupon = c;
          break;
        }
      }
      if (coupon != null && coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
        continue;
      }
      out.add(OfferView(discount: d, coupon: coupon));
    }
    return out;
  }
}
