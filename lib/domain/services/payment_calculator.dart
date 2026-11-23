import '../../core/money/money.dart';
import '../enums.dart';
import '../models/payment_refund.dart';

/// Balance and status maths. The client never decides "paid": this runs over
/// payments the (mock, later real) backend has marked verified.
abstract final class PaymentCalculator {
  static Money verifiedPaid(Iterable<Payment> payments) =>
      payments.fold(Money.zero, (sum, p) => sum + p.verifiedAmount);

  /// Remaining Due = Final Booking Total − Total Successful Payments,
  /// floored at zero.
  static Money remainingDue(Money total, Iterable<Payment> payments) =>
      (total - verifiedPaid(payments)).clampMin(Money.zero);

  /// Verified payments minus completed refunds.
  static Money netPaid(Iterable<Payment> payments, Money refunded) =>
      (verifiedPaid(payments) - refunded).clampMin(Money.zero);

  /// Configured advance (basis points of total), never above the total.
  static Money advanceAmount(Money total, int advanceBp) =>
      total.percent(advanceBp).clampMax(total);

  static PaymentStatus statusFor({
    required Money total,
    required Iterable<Payment> payments,
    Money refunded = Money.zero,
  }) {
    final paid = verifiedPaid(payments);
    if (refunded.isPositive && paid.isPositive) {
      return refunded >= paid
          ? PaymentStatus.refunded
          : PaymentStatus.partiallyRefunded;
    }
    if (total.isPositive && paid >= total) return PaymentStatus.paid;
    if (paid.isPositive) return PaymentStatus.partiallyPaid;
    final latest = payments.isEmpty ? null : payments.last.status;
    if (payments.any((p) =>
        p.status == TransactionStatus.pendingVerification ||
        p.status == TransactionStatus.initiated)) {
      return PaymentStatus.pendingVerification;
    }
    if (latest == TransactionStatus.failed ||
        latest == TransactionStatus.timedOut) {
      return PaymentStatus.failed;
    }
    return PaymentStatus.unpaid;
  }
}
