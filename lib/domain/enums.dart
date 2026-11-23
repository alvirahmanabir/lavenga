/// Independent state machines. Booking, payment, transaction, refund, hold
/// and ticket status never derive from one another.
enum UserRole { customer, manager, admin }

enum AccountStatus { active, suspended, blacklisted, deactivated }

enum BookingStatus {
  pendingReview,
  confirmed,
  inProgress,
  completed,
  rejected,
  cancelled,
  expired,
  noShow,
}

enum PaymentStatus {
  unpaid,
  pendingVerification,
  partiallyPaid,
  paid,
  failed,
  refunded,
  partiallyRefunded,
}

enum TransactionStatus {
  initiated,
  pendingVerification,
  verified,
  failed,
  cancelled,
  timedOut,
}

enum PaymentKind { full, advance, balance }

enum PaymentMethod { bkash, nagad, card, bank }

enum RefundStatus {
  requested,
  underManagerReview,
  rejectedByManager,
  forwardedToAdmin,
  approved,
  rejectedByAdmin,
  processing,
  refunded,
  failed,
}

enum HoldStatus { active, converted, expired, released }

enum TicketStatus {
  open,
  awaitingCustomer,
  awaitingStaff,
  escalated,
  resolved,
  closed,
}

enum DiscountKind { percentage, fixed }

enum DiscountScope { global, space, category, customer }

enum SlotState { available, selected, unavailable, pending, confirmed, past }

enum SpaceStatus { active, inactive, archived }

enum SpaceSort { recommended, priceLow, priceHigh, rating, popularity, newest }

enum Gender { female, male, other }

enum StaffPermission {
  manageSpaces,
  createSpaces,
  managePricing,
  confirmBookings,
  cancelBookings,
  viewPayments,
  viewCustomers,
  handleRefunds,
  handleSupport,
  viewReports,
}

String enumToJson(Enum e) => e.name;
T enumFromJson<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
        BookingStatus.pendingReview => 'Pending review',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.inProgress => 'In progress',
        BookingStatus.completed => 'Completed',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.expired => 'Expired',
        BookingStatus.noShow => 'No-show',
      };

  /// Statuses that occupy the space on the calendar.
  bool get occupiesSlot =>
      this == BookingStatus.pendingReview ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.inProgress;

  bool get isClosed =>
      this == BookingStatus.completed ||
      this == BookingStatus.rejected ||
      this == BookingStatus.cancelled ||
      this == BookingStatus.expired ||
      this == BookingStatus.noShow;
}

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.unpaid => 'Unpaid',
        PaymentStatus.pendingVerification => 'Verifying payment',
        PaymentStatus.partiallyPaid => 'Partially paid',
        PaymentStatus.paid => 'Paid',
        PaymentStatus.failed => 'Payment failed',
        PaymentStatus.refunded => 'Refunded',
        PaymentStatus.partiallyRefunded => 'Partially refunded',
      };
}

extension TransactionStatusX on TransactionStatus {
  String get label => switch (this) {
        TransactionStatus.initiated => 'Initiated',
        TransactionStatus.pendingVerification => 'Verifying',
        TransactionStatus.verified => 'Verified',
        TransactionStatus.failed => 'Failed',
        TransactionStatus.cancelled => 'Cancelled',
        TransactionStatus.timedOut => 'Timed out',
      };
}

extension RefundStatusX on RefundStatus {
  String get label => switch (this) {
        RefundStatus.requested => 'Requested',
        RefundStatus.underManagerReview => 'Under review',
        RefundStatus.rejectedByManager => 'Rejected by manager',
        RefundStatus.forwardedToAdmin => 'With administrator',
        RefundStatus.approved => 'Approved',
        RefundStatus.rejectedByAdmin => 'Rejected',
        RefundStatus.processing => 'Processing',
        RefundStatus.refunded => 'Refunded',
        RefundStatus.failed => 'Refund failed',
      };

  bool get isTerminal =>
      this == RefundStatus.rejectedByManager ||
      this == RefundStatus.rejectedByAdmin ||
      this == RefundStatus.refunded ||
      this == RefundStatus.failed;
}

extension TicketStatusX on TicketStatus {
  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.awaitingCustomer => 'Awaiting customer',
        TicketStatus.awaitingStaff => 'Awaiting support',
        TicketStatus.escalated => 'Escalated',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
      };
}

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.bkash => 'bKash',
        PaymentMethod.nagad => 'Nagad',
        PaymentMethod.card => 'Credit / debit card',
        PaymentMethod.bank => 'Internet banking',
      };
}

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.manager => 'Platform Manager',
        UserRole.admin => 'Administrator',
      };

  String get prefix => switch (this) {
        UserRole.customer => '/c',
        UserRole.manager => '/m',
        UserRole.admin => '/a',
      };

  String get home => switch (this) {
        UserRole.customer => '/c/home',
        UserRole.manager => '/m/dashboard',
        UserRole.admin => '/a/dashboard',
      };
}

extension StaffPermissionX on StaffPermission {
  String get label => switch (this) {
        StaffPermission.manageSpaces => 'Edit assigned spaces',
        StaffPermission.createSpaces => 'Create new spaces',
        StaffPermission.managePricing => 'Change pricing',
        StaffPermission.confirmBookings => 'Confirm bookings',
        StaffPermission.cancelBookings => 'Cancel bookings',
        StaffPermission.viewPayments => 'View payment records',
        StaffPermission.viewCustomers => 'View customers',
        StaffPermission.handleRefunds => 'Review refund requests',
        StaffPermission.handleSupport => 'Handle support tickets',
        StaffPermission.viewReports => 'View reports',
      };
}
