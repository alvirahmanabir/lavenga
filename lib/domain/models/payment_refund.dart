import '../../core/money/money.dart';
import '../enums.dart';
import 'booking.dart';
import 'json_helpers.dart';

/// One gateway attempt against a [Payment]. A redirect or client "success"
/// is never proof; only a backend-verified transaction counts.
class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.paymentId,
    required this.amount,
    required this.method,
    required this.status,
    required this.gatewayRef,
    required this.at,
    this.failureReason,
  });

  final String id;
  final String paymentId;
  final Money amount;
  final PaymentMethod method;
  final TransactionStatus status;

  /// Gateway transaction reference (SSLCommerz bank_tran_id / val_id later).
  final String gatewayRef;
  final DateTime at;
  final String? failureReason;

  Map<String, dynamic> toJson() => {
        'id': id,
        'payment_id': paymentId,
        'amount_minor': amount.minor,
        'method': method.name,
        'status': status.name,
        'gateway_ref': gatewayRef,
        'at': dateJson(at),
        'failure_reason': failureReason,
      };

  factory PaymentTransaction.fromJson(Map<String, dynamic> j) =>
      PaymentTransaction(
        id: j['id'] as String,
        paymentId: j['payment_id'] as String,
        amount: jMoney(j['amount_minor']),
        method: enumFromJson(PaymentMethod.values, j['method'], PaymentMethod.card),
        status: enumFromJson(
            TransactionStatus.values, j['status'], TransactionStatus.failed),
        gatewayRef: j['gateway_ref'] as String,
        at: jDate(j['at']),
        failureReason: j['failure_reason'] as String?,
      );
}

/// A payment intent against a booking (advance, full or balance).
class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.bookingRef,
    required this.customerId,
    required this.kind,
    required this.amount,
    required this.createdAt,
    this.transactions = const [],
  });

  final String id;
  final String bookingId;
  final String bookingRef;
  final String customerId;
  final PaymentKind kind;
  final Money amount;
  final DateTime createdAt;
  final List<PaymentTransaction> transactions;

  PaymentTransaction? get latest => transactions.isEmpty ? null : transactions.last;
  TransactionStatus get status =>
      latest?.status ?? TransactionStatus.initiated;
  bool get isVerified => status == TransactionStatus.verified;
  Money get verifiedAmount => isVerified ? amount : Money.zero;

  Payment copyWith({List<PaymentTransaction>? transactions}) => Payment(
        id: id,
        bookingId: bookingId,
        bookingRef: bookingRef,
        customerId: customerId,
        kind: kind,
        amount: amount,
        createdAt: createdAt,
        transactions: transactions ?? this.transactions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'booking_ref': bookingRef,
        'customer_id': customerId,
        'kind': kind.name,
        'amount_minor': amount.minor,
        'created_at': dateJson(createdAt),
        'transactions': [for (final t in transactions) t.toJson()],
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        bookingId: j['booking_id'] as String,
        bookingRef: j['booking_ref'] as String,
        customerId: j['customer_id'] as String,
        kind: enumFromJson(PaymentKind.values, j['kind'], PaymentKind.full),
        amount: jMoney(j['amount_minor']),
        createdAt: jDate(j['created_at']),
        transactions: [
          for (final t in jList(j['transactions'])) PaymentTransaction.fromJson(t)
        ],
      );
}

class RefundTransaction {
  const RefundTransaction({
    required this.id,
    required this.refundId,
    required this.amount,
    required this.status,
    required this.gatewayRef,
    required this.at,
  });

  final String id;
  final String refundId;
  final Money amount;
  final TransactionStatus status;
  final String gatewayRef;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'refund_id': refundId,
        'amount_minor': amount.minor,
        'status': status.name,
        'gateway_ref': gatewayRef,
        'at': dateJson(at),
      };

  factory RefundTransaction.fromJson(Map<String, dynamic> j) =>
      RefundTransaction(
        id: j['id'] as String,
        refundId: j['refund_id'] as String,
        amount: jMoney(j['amount_minor']),
        status: enumFromJson(
            TransactionStatus.values, j['status'], TransactionStatus.failed),
        gatewayRef: j['gateway_ref'] as String,
        at: jDate(j['at']),
      );
}

class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.bookingId,
    required this.bookingRef,
    required this.customerId,
    required this.customerName,
    required this.reason,
    required this.requested,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approved,
    this.managerNote,
    this.adminNote,
    this.customerNote,
    this.timeline = const [],
    this.transactions = const [],
  });

  final String id;
  final String bookingId;
  final String bookingRef;
  final String customerId;
  final String customerName;
  final String reason;
  final Money requested;

  /// Requested, approved and refunded amounts are tracked separately.
  final Money? approved;
  final RefundStatus status;

  /// Internal notes are hidden from customers; [customerNote] is safe to show.
  final String? managerNote;
  final String? adminNote;
  final String? customerNote;
  final List<TimelineEvent> timeline;
  final List<RefundTransaction> transactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Money get refunded => transactions
      .where((t) => t.status == TransactionStatus.verified)
      .fold(Money.zero, (a, t) => a + t.amount);

  RefundRequest copyWith({
    RefundStatus? status,
    Money? approved,
    String? managerNote,
    String? adminNote,
    String? customerNote,
    List<TimelineEvent>? timeline,
    List<RefundTransaction>? transactions,
    DateTime? updatedAt,
  }) =>
      RefundRequest(
        id: id,
        bookingId: bookingId,
        bookingRef: bookingRef,
        customerId: customerId,
        customerName: customerName,
        reason: reason,
        requested: requested,
        approved: approved ?? this.approved,
        status: status ?? this.status,
        managerNote: managerNote ?? this.managerNote,
        adminNote: adminNote ?? this.adminNote,
        customerNote: customerNote ?? this.customerNote,
        timeline: timeline ?? this.timeline,
        transactions: transactions ?? this.transactions,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'booking_ref': bookingRef,
        'customer_id': customerId,
        'customer_name': customerName,
        'reason': reason,
        'requested_minor': requested.minor,
        'approved_minor': approved?.minor,
        'status': status.name,
        'manager_note': managerNote,
        'admin_note': adminNote,
        'customer_note': customerNote,
        'timeline': [for (final t in timeline) t.toJson()],
        'transactions': [for (final t in transactions) t.toJson()],
        'created_at': dateJson(createdAt),
        'updated_at': dateJson(updatedAt),
      };

  factory RefundRequest.fromJson(Map<String, dynamic> j) => RefundRequest(
        id: j['id'] as String,
        bookingId: j['booking_id'] as String,
        bookingRef: j['booking_ref'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String,
        reason: j['reason'] as String,
        requested: jMoney(j['requested_minor']),
        approved: j['approved_minor'] == null ? null : jMoney(j['approved_minor']),
        status: enumFromJson(RefundStatus.values, j['status'], RefundStatus.requested),
        managerNote: j['manager_note'] as String?,
        adminNote: j['admin_note'] as String?,
        customerNote: j['customer_note'] as String?,
        timeline: [for (final t in jList(j['timeline'])) TimelineEvent.fromJson(t)],
        transactions: [
          for (final t in jList(j['transactions'])) RefundTransaction.fromJson(t)
        ],
        createdAt: jDate(j['created_at']),
        updatedAt: jDate(j['updated_at']),
      );
}
