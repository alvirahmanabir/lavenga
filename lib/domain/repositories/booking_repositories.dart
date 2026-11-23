import '../../core/money/money.dart';
import '../enums.dart';
import '../models/booking.dart';
import '../models/payment_refund.dart';
import '../models/promo_social.dart';
import '../models/user.dart';
import '../services/policies.dart';
import '../services/pricing_service.dart';

/// One cart entry before checkout. Revalidated on every change.
class CartLine {
  const CartLine({
    required this.id,
    required this.spaceId,
    required this.schedule,
    this.notes = '',
  });
  final String id;
  final String spaceId;
  final BookingSchedule schedule;
  final String notes;

  CartLine copyWith({BookingSchedule? schedule, String? notes}) => CartLine(
        id: id,
        spaceId: spaceId,
        schedule: schedule ?? this.schedule,
        notes: notes ?? this.notes,
      );
}

class BookingFilter {
  const BookingFilter({
    this.text = '',
    this.statuses = const {},
    this.paymentStatuses = const {},
    this.from,
    this.to,
    this.customerId,
  });
  final String text;
  final Set<BookingStatus> statuses;
  final Set<PaymentStatus> paymentStatuses;
  final DateTime? from;
  final DateTime? to;
  final String? customerId;

  BookingFilter copyWith({
    String? text,
    Set<BookingStatus>? statuses,
    Set<PaymentStatus>? paymentStatuses,
    DateTime? from,
    DateTime? to,
    String? customerId,
  }) =>
      BookingFilter(
        text: text ?? this.text,
        statuses: statuses ?? this.statuses,
        paymentStatuses: paymentStatuses ?? this.paymentStatuses,
        from: from ?? this.from,
        to: to ?? this.to,
        customerId: customerId ?? this.customerId,
      );
}

abstract class BookingRepository {
  /// Indicative quote only; the backend recomputes the final price.
  Future<QuoteResult> quote({
    required String customerId,
    required List<CartLine> lines,
    String? couponCode,
  });

  /// Atomically validates every line, then creates the order with a
  /// time-limited hold. Throws [SlotConflict] naming the first conflict,
  /// [ValidationFailure] for rule violations, [Forbidden] for restricted
  /// accounts. Mock only: real exclusivity needs transactional SQL.
  Future<Booking> createOrder({
    required AppUser customer,
    required List<CartLine> lines,
    String? couponCode,
    String notes = '',
  });

  Future<Booking> getBooking(String id);
  Future<List<Booking>> listForCustomer(String customerId);

  /// Staff search. Results are filtered by the actor's studio scope.
  Future<List<Booking>> search(BookingFilter filter, {required AppUser actor});

  Future<Booking> cancelByCustomer(String bookingId, {required AppUser actor});

  /// Staff transition (confirm, reject, cancel, in progress, complete, no-show).
  /// Cancel/reject require [reason]. Checks [BookingTransitions] and permissions.
  Future<Booking> updateStatus(String bookingId, BookingStatus to,
      {required AppUser actor, String? reason});
  Future<Booking> addInternalNote(String bookingId, String text,
      {required AppUser actor});

  /// Administrator modification with full revalidation.
  Future<Booking> rescheduleItem(String bookingId, String itemId, BookingSchedule schedule,
      {required AppUser actor});

  /// Expires unpaid holds whose time has run out; returns how many.
  Future<int> expireHolds();
}

enum GatewayOutcome { success, failure, cancelled, timeout }

abstract class PaymentRepository {
  /// Creates a payment intent and a pending transaction. [kind] full and
  /// balance charge the remaining due; advance charges the configured advance.
  Future<Payment> startPayment({
    required String bookingId,
    required PaymentKind kind,
    required PaymentMethod method,
    required AppUser actor,
  });

  /// MOCK ONLY: simulates the gateway returning to the app and the backend
  /// verifying the result. The real flow opens SSLCommerz hosted checkout,
  /// then fetches the verified status from the backend; a redirect is never proof.
  Future<Payment> simulateGateway(String paymentId, GatewayOutcome outcome);

  /// Retries a failed or cancelled payment with a new transaction.
  Future<Payment> retry(String paymentId, PaymentMethod method);

  Future<Payment> getPayment(String id);
  Future<List<Payment>> listForBooking(String bookingId);
  Future<List<Payment>> listForCustomer(String customerId);
  Future<List<Payment>> listForStaff({required AppUser actor, String query = ''});

  /// Administrator reconciliation of a pending or disputed transaction.
  Future<Payment> reconcile(String paymentId,
      {required bool verified, required AppUser actor});
}

abstract class RefundRepository {
  Future<RefundRequest> request({
    required String bookingId,
    required Money amount,
    required String reason,
    required AppUser actor,
  });
  Future<RefundRequest> getRefund(String id);
  Future<List<RefundRequest>> listForCustomer(String customerId);
  Future<List<RefundRequest>> listForStaff({required AppUser actor});

  /// Applies one workflow action. Validates state and role through
  /// [RefundWorkflow]; mock initiate also simulates gateway completion.
  Future<RefundRequest> perform(
    String refundId,
    RefundAction action, {
    required AppUser actor,
    String? note,
    String? customerNote,
    Money? approvedAmount,
  });

  /// Maximum the customer can still request for a booking.
  Future<Money> refundableAmount(String bookingId);
}

class OfferView {
  const OfferView({required this.discount, this.coupon});
  final Discount discount;
  final Coupon? coupon;
}

abstract class DiscountRepository {
  Future<List<Discount>> listDiscounts();
  Future<List<Coupon>> listCoupons();
  Future<Discount> saveDiscount(Discount discount, {required AppUser actor});
  Future<Coupon> saveCoupon(Coupon coupon, {required AppUser actor});

  /// Currently valid offers for customers (special offers section).
  Future<List<OfferView>> activeOffers();
}
