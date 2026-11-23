import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/session/session.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/payment_refund.dart';
import '../../../domain/models/promo_social.dart';
import '../../../domain/repositories/account_repositories.dart';
import '../../../domain/repositories/engagement_repositories.dart';
import '../../../domain/services/availability_service.dart';

final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(bookingRepositoryProvider).listForCustomer(user.id);
});

final bookingPaymentsProvider =
    FutureProvider.autoDispose.family<List<Payment>, String>((ref, bookingId) {
  ref.watch(dbVersionProvider);
  return ref.watch(paymentRepositoryProvider).listForBooking(bookingId);
});

final paymentProvider = FutureProvider.autoDispose.family<Payment, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(paymentRepositoryProvider).getPayment(id);
});

final myRefundsProvider = FutureProvider.autoDispose<List<RefundRequest>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(refundRepositoryProvider).listForCustomer(user.id);
});

final refundProvider = FutureProvider.autoDispose.family<RefundRequest, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(refundRepositoryProvider).getRefund(id);
});

final refundableProvider = FutureProvider.autoDispose.family<Money, String>((ref, bookingId) {
  ref.watch(dbVersionProvider);
  return ref.watch(refundRepositoryProvider).refundableAmount(bookingId);
});

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(supportRepositoryProvider).listForCustomer(user.id);
});

final ticketProvider = FutureProvider.autoDispose.family<SupportTicket, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(supportRepositoryProvider).get(id);
});

final myReviewsProvider = FutureProvider.autoDispose<List<Review>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(reviewRepositoryProvider).forCustomer(user.id);
});

final eligibleReviewItemsProvider = FutureProvider.autoDispose<List<ReviewableItem>>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(reviewRepositoryProvider).eligibleItems(user.id);
});

final customerSummaryProvider = FutureProvider.autoDispose<CustomerSummary>((ref) {
  ref.watch(dbVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(userRepositoryProvider).customerSummary(user.id);
});

final spaceBusyProvider =
    FutureProvider.autoDispose.family<List<BusyInterval>, String>((ref, spaceId) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).busyIntervals(spaceId);
});

/// Coupon code typed in the cart, carried to checkout.
class CouponCodeNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String code) => state = code.trim();
}

final cartCouponProvider = NotifierProvider<CouponCodeNotifier, String>(CouponCodeNotifier.new);
