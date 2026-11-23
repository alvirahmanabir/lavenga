import 'package:flutter_test/flutter_test.dart';
import 'package:lavenga/core/money/money.dart';
import 'package:lavenga/domain/enums.dart';
import 'package:lavenga/domain/models/promo_social.dart';
import 'package:lavenga/domain/services/payment_calculator.dart';
import 'package:lavenga/domain/services/policies.dart';

void main() {
  group('RefundWorkflow', () {
    test('manager path: requested -> review -> forwarded -> approved -> refunded', () {
      var s = RefundStatus.requested;
      s = RefundWorkflow.next(s, RefundAction.startReview)!;
      expect(s, RefundStatus.underManagerReview);
      s = RefundWorkflow.next(s, RefundAction.forward)!;
      expect(s, RefundStatus.forwardedToAdmin);
      s = RefundWorkflow.next(s, RefundAction.approve)!;
      expect(s, RefundStatus.approved);
      s = RefundWorkflow.next(s, RefundAction.initiate)!;
      expect(s, RefundStatus.processing);
      expect(RefundWorkflow.next(s, RefundAction.markRefunded), RefundStatus.refunded);
    });

    test('manager cannot approve; admin cannot skip forwarding', () {
      expect(RefundWorkflow.next(RefundStatus.requested, RefundAction.approve), isNull);
      expect(RefundWorkflow.allowedActions(RefundStatus.forwardedToAdmin, UserRole.manager),
          isEmpty);
      expect(RefundWorkflow.allowedActions(RefundStatus.forwardedToAdmin, UserRole.admin),
          containsAll([RefundAction.approve, RefundAction.rejectByAdmin]));
      expect(RefundWorkflow.allowedActions(RefundStatus.requested, UserRole.customer), isEmpty);
    });

    test('failed refunds can be retried', () {
      expect(RefundWorkflow.next(RefundStatus.failed, RefundAction.initiate),
          RefundStatus.processing);
    });
  });

  group('BookingTransitions', () {
    test('terminal states have no exits', () {
      expect(BookingTransitions.from(BookingStatus.completed), isEmpty);
      expect(BookingTransitions.allowed(BookingStatus.pendingReview, BookingStatus.confirmed),
          isTrue);
      expect(BookingTransitions.allowed(BookingStatus.rejected, BookingStatus.confirmed),
          isFalse);
    });
  });

  group('CancellationPolicy.refundEstimate', () {
    const tiers = [RefundTier(72, 10000), RefundTier(24, 5000), RefundTier(0, 0)];
    final now = DateTime.utc(2026, 6, 1, 12);
    Money est(int hours) => CancellationPolicy.refundEstimate(
        netPaid: const Money.taka(1000),
        sessionStart: now.add(Duration(hours: hours)),
        now: now,
        tiers: tiers);

    test('tiers apply by hours before the session', () {
      expect(est(100), const Money.taka(1000));
      expect(est(30), const Money.taka(500));
      expect(est(5), Money.zero);
    });
  });

  group('PaymentCalculator', () {
    test('remaining due is floored at zero and advance capped at total', () {
      expect(PaymentCalculator.remainingDue(const Money.taka(1000), const []),
          const Money.taka(1000));
      expect(PaymentCalculator.advanceAmount(const Money.taka(1000), 3000),
          const Money.taka(300));
      expect(PaymentCalculator.advanceAmount(const Money.taka(1000), 20000),
          const Money.taka(1000));
      expect(PaymentCalculator.statusFor(total: const Money.taka(1000), payments: const []),
          PaymentStatus.unpaid);
    });
  });
}
