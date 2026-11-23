import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_store.dart';
import '../../data/mock/mock_account_repositories.dart';
import '../../data/mock/mock_booking_repository.dart';
import '../../data/mock/mock_catalogue_repositories.dart';
import '../../data/mock/mock_context.dart';
import '../../data/mock/mock_database.dart';
import '../../data/mock/mock_engagement_repositories.dart';
import '../../data/mock/mock_payment_refund_repositories.dart';
import '../../data/mock/mock_stats_repositories.dart';
import '../../domain/repositories/account_repositories.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/repositories/catalogue_repositories.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../clock/clock.dart';

/// Overridden in main() / tests with real instances.
final localStoreProvider = Provider<LocalStore>((ref) => MemoryLocalStore());
final databaseProvider = Provider<MockDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Simulated network latency; tests override with Duration.zero.
final mockLatencyProvider = Provider<Duration>((ref) => const Duration(milliseconds: 80));

/// Bumped after every mock mutation. Data providers watch it so every screen
/// refreshes. With Supabase, Realtime events become refresh signals the same
/// way (re-fetch authoritative records after an event).
class DbVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dbVersionProvider = NotifierProvider<DbVersionNotifier, int>(DbVersionNotifier.new);

final mockContextProvider = Provider<MockContext>((ref) => MockContext(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      latency: ref.watch(mockLatencyProvider),
      onChange: () => ref.read(dbVersionProvider.notifier).bump(),
    ));

// ---- Repository bindings: the ONE place mocks are chosen. ---------------
// Swap each for a Supabase-backed implementation later; UI is unaffected.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => MockAuthRepository(ref.watch(mockContextProvider)));
final userRepositoryProvider =
    Provider<UserRepository>((ref) => MockUserRepository(ref.watch(mockContextProvider)));
final studioRepositoryProvider =
    Provider<StudioRepository>((ref) => MockStudioRepository(ref.watch(mockContextProvider)));
final spaceRepositoryProvider =
    Provider<SpaceRepository>((ref) => MockSpaceRepository(ref.watch(mockContextProvider)));
final favoriteRepositoryProvider =
    Provider<FavoriteRepository>((ref) => MockFavoriteRepository(ref.watch(mockContextProvider)));
final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => MockBookingRepository(ref.watch(mockContextProvider)));
final paymentRepositoryProvider =
    Provider<PaymentRepository>((ref) => MockPaymentRepository(ref.watch(mockContextProvider)));
final refundRepositoryProvider =
    Provider<RefundRepository>((ref) => MockRefundRepository(ref.watch(mockContextProvider)));
final discountRepositoryProvider =
    Provider<DiscountRepository>((ref) => MockDiscountRepository(ref.watch(mockContextProvider)));
final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => MockReviewRepository(ref.watch(mockContextProvider)));
final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => MockSupportRepository(ref.watch(mockContextProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => MockNotificationRepository(ref.watch(mockContextProvider)));
final managerRepositoryProvider =
    Provider<ManagerRepository>((ref) => MockManagerRepository(ref.watch(mockContextProvider)));
final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => MockAdminRepository(ref.watch(mockContextProvider)));
