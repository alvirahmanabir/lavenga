import '../../core/money/money.dart';
import '../enums.dart';
import '../models/booking.dart';
import '../models/promo_social.dart';
import '../models/user.dart';

/// Role and scope checks. Hiding a button is a UX nicety only; mock
/// repositories re-check these and the real backend must enforce them.
abstract final class PermissionPolicy {
  static bool can(AppUser user, StaffPermission permission) {
    if (user.isAdmin) return true;
    if (user.isManager) {
      return user.manager?.permissions.contains(permission) ?? false;
    }
    return false;
  }

  static bool managesStudio(AppUser user, String studioId) {
    if (user.isAdmin) return true;
    if (user.isManager) return user.manager?.studioIds.contains(studioId) ?? false;
    return false;
  }

  /// Staff may see a booking if any item is in their scope.
  static bool canSeeBooking(AppUser user, Booking booking) {
    if (user.isAdmin) return true;
    if (user.isCustomer) return booking.customerId == user.id;
    return booking.items.any((i) => managesStudio(user, i.studioId));
  }
}

abstract final class CancellationPolicy {
  /// Customers may cancel only before confirmation.
  static bool canCustomerCancel(Booking b) =>
      b.status == BookingStatus.pendingReview;

  /// Managers/administrators may cancel until the session has finished.
  static bool canStaffCancel(Booking b) =>
      b.status == BookingStatus.pendingReview ||
      b.status == BookingStatus.confirmed;

  /// Whether the customer may open a refund request.
  static bool canRequestRefund({
    required Booking booking,
    required Money netPaid,
    required Money alreadyRequestedOpen,
  }) {
    if (!netPaid.isPositive) return false;
    if (booking.status == BookingStatus.completed) return false;
    return (netPaid - alreadyRequestedOpen).isPositive;
  }

  /// Policy-based refund estimate for display only. The backend returns the
  /// authoritative figure; this uses the configured tiers.
  static Money refundEstimate({
    required Money netPaid,
    required DateTime sessionStart,
    required DateTime now,
    required List<RefundTier> tiers,
  }) {
    final hoursAhead = sessionStart.difference(now).inHours;
    final sorted = [...tiers]..sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));
    for (final tier in sorted) {
      if (hoursAhead >= tier.hoursBefore) return netPaid.percent(tier.refundBp);
    }
    return Money.zero;
  }
}

abstract final class BookingTransitions {
  static Set<BookingStatus> from(BookingStatus s) => switch (s) {
        BookingStatus.pendingReview => {
            BookingStatus.confirmed,
            BookingStatus.rejected,
            BookingStatus.cancelled,
            BookingStatus.expired,
          },
        BookingStatus.confirmed => {
            BookingStatus.inProgress,
            BookingStatus.completed,
            BookingStatus.cancelled,
            BookingStatus.noShow,
          },
        BookingStatus.inProgress => {BookingStatus.completed},
        _ => const {},
      };

  static bool allowed(BookingStatus from, BookingStatus to) =>
      BookingTransitions.from(from).contains(to);
}

enum RefundAction {
  startReview,
  forward,
  rejectByManager,
  approve,
  rejectByAdmin,
  initiate,
  markRefunded,
  markFailed,
}

/// Pure transition table for refunds. Role checks are separate from state
/// checks: [allowedActions] combines both.
abstract final class RefundWorkflow {
  static RefundStatus? next(RefundStatus from, RefundAction action) {
    switch (action) {
      case RefundAction.startReview:
        return from == RefundStatus.requested ? RefundStatus.underManagerReview : null;
      case RefundAction.forward:
        return (from == RefundStatus.requested || from == RefundStatus.underManagerReview)
            ? RefundStatus.forwardedToAdmin
            : null;
      case RefundAction.rejectByManager:
        return (from == RefundStatus.requested || from == RefundStatus.underManagerReview)
            ? RefundStatus.rejectedByManager
            : null;
      case RefundAction.approve:
        return from == RefundStatus.forwardedToAdmin ? RefundStatus.approved : null;
      case RefundAction.rejectByAdmin:
        return from == RefundStatus.forwardedToAdmin ? RefundStatus.rejectedByAdmin : null;
      case RefundAction.initiate:
        return (from == RefundStatus.approved || from == RefundStatus.failed)
            ? RefundStatus.processing
            : null;
      case RefundAction.markRefunded:
        return from == RefundStatus.processing ? RefundStatus.refunded : null;
      case RefundAction.markFailed:
        return from == RefundStatus.processing ? RefundStatus.failed : null;
    }
  }

  static const _managerActions = {
    RefundAction.startReview,
    RefundAction.forward,
    RefundAction.rejectByManager,
  };
  static const _adminActions = {
    RefundAction.approve,
    RefundAction.rejectByAdmin,
    RefundAction.initiate,
    RefundAction.markRefunded,
    RefundAction.markFailed,
  };

  static bool roleMayPerform(UserRole role, RefundAction action) =>
      switch (role) {
        UserRole.manager => _managerActions.contains(action),
        UserRole.admin => _adminActions.contains(action),
        UserRole.customer => false,
      };

  static List<RefundAction> allowedActions(RefundStatus status, UserRole role) => [
        for (final a in RefundAction.values)
          if (roleMayPerform(role, a) && next(status, a) != null) a,
      ];
}
