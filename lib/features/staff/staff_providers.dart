import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/clock.dart';
import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/account_repositories.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/repositories/catalogue_repositories.dart';
import '../../domain/repositories/engagement_repositories.dart';

/// Providers shared by the manager and administrator screens. Every one
/// watches [dbVersionProvider] so mutations refresh all open screens.

class StaffBookingFilterNotifier extends Notifier<BookingFilter> {
  @override
  BookingFilter build() => const BookingFilter();
  void set(BookingFilter filter) => state = filter;
}

final staffBookingFilterProvider =
    NotifierProvider<StaffBookingFilterNotifier, BookingFilter>(StaffBookingFilterNotifier.new);

final staffBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  ref.watch(dbVersionProvider);
  final filter = ref.watch(staffBookingFilterProvider);
  final actor = ref.watch(currentUserProvider);
  return ref.watch(bookingRepositoryProvider).search(filter, actor: actor);
});

final bookingPaymentsProvider =
    FutureProvider.autoDispose.family<List<Payment>, String>((ref, bookingId) {
  ref.watch(dbVersionProvider);
  return ref.watch(paymentRepositoryProvider).listForBooking(bookingId);
});

final staffRefundsProvider = FutureProvider.autoDispose<List<RefundRequest>>((ref) {
  ref.watch(dbVersionProvider);
  final actor = ref.watch(currentUserProvider);
  return ref.watch(refundRepositoryProvider).listForStaff(actor: actor);
});

final refundProvider = FutureProvider.autoDispose.family<RefundRequest, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(refundRepositoryProvider).getRefund(id);
});

/// Refund requests for one booking (filtered from the staff-scoped list).
final bookingRefundsProvider =
    FutureProvider.autoDispose.family<List<RefundRequest>, String>((ref, bookingId) async {
  final all = await ref.watch(staffRefundsProvider.future);
  return [for (final r in all) if (r.bookingId == bookingId) r];
});

final staffTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  ref.watch(dbVersionProvider);
  final actor = ref.watch(currentUserProvider);
  return ref.watch(supportRepositoryProvider).listForStaff(actor: actor);
});

final ticketProvider = FutureProvider.autoDispose.family<SupportTicket, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(supportRepositoryProvider).get(id);
});

final customerListProvider =
    FutureProvider.autoDispose.family<List<AppUser>, String>((ref, query) {
  ref.watch(dbVersionProvider);
  return ref
      .watch(userRepositoryProvider)
      .listUsers(role: UserRole.customer, query: query.isEmpty ? null : query);
});

final customerUserProvider = FutureProvider.autoDispose.family<AppUser, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(userRepositoryProvider).getUser(id);
});

final customerSummaryProvider =
    FutureProvider.autoDispose.family<CustomerSummary, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(userRepositoryProvider).customerSummary(id);
});

final customerBookingsProvider =
    FutureProvider.autoDispose.family<List<Booking>, String>((ref, customerId) {
  ref.watch(dbVersionProvider);
  final actor = ref.watch(currentUserProvider);
  return ref
      .watch(bookingRepositoryProvider)
      .search(BookingFilter(customerId: customerId), actor: actor);
});

/// Spaces the signed-in staff member may see (managers: assigned studios).
final staffSpacesProvider = FutureProvider.autoDispose<List<StudioSpace>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(spaceRepositoryProvider).listSpaces(SpaceQuery(
        studioIds: user.isAdmin ? null : (user.manager?.studioIds ?? const []),
        includeInactive: true,
      ));
});

final spaceBlocksProvider =
    FutureProvider.autoDispose.family<List<SpaceAvailability>, String>((ref, spaceId) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).listBlocks(spaceId);
});

/// Dashboard for the last [days] days (0 = all time), scoped by role.
final staffDashboardProvider =
    FutureProvider.autoDispose.family<DashboardStats, int>((ref, days) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  final from = days == 0 ? null : ref.watch(clockProvider).now().subtract(Duration(days: days));
  return user.isAdmin
      ? ref.watch(adminRepositoryProvider).dashboard(user, from: from)
      : ref.watch(managerRepositoryProvider).dashboard(user, from: from);
});

final staffReportProvider =
    FutureProvider.autoDispose.family<ReportData, (ReportKind, int)>((ref, key) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  final from = key.$2 == 0 ? null : ref.watch(clockProvider).now().subtract(Duration(days: key.$2));
  return user.isAdmin
      ? ref.watch(adminRepositoryProvider).report(user, key.$1, from: from)
      : ref.watch(managerRepositoryProvider).report(user, key.$1, from: from);
});
