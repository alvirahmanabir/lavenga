import '../enums.dart';
import '../models/user.dart';
import '../../core/money/money.dart';

abstract class AuthRepository {
  /// Restores a previous session on app start, or null.
  Future<AppUser?> restoreSession();

  /// Throws [ValidationFailure] for wrong credentials. A restricted account
  /// still returns its user so the UI can show the neutral restriction notice.
  Future<AppUser> signIn({required String identifier, required String password});

  /// Creates an unverified account; the caller then runs [verifyOtp].
  Future<AppUser> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
  });

  Future<AppUser> verifyOtp({required String userId, required String code});
  Future<void> resendOtp(String userId);

  /// Returns the user id the OTP was "sent" to (mock: code is always 123456).
  Future<String> requestPasswordReset(String identifier);
  Future<void> resetPassword({
    required String userId,
    required String code,
    required String newPassword,
  });
  Future<void> signOut();
}

class CustomerSummary {
  const CustomerSummary({
    required this.bookings,
    required this.lifetimeSpend,
    required this.refunded,
    required this.outstanding,
    required this.reviews,
    required this.tickets,
  });
  final int bookings;

  /// Verified payments minus completed refunds.
  final Money lifetimeSpend;
  final Money refunded;
  final Money outstanding;
  final int reviews;
  final int tickets;
}

abstract class UserRepository {
  Future<AppUser> getUser(String id);
  Future<List<AppUser>> listUsers({UserRole? role, String? query});

  /// Customers edit only permitted fields. Registered email and phone are
  /// never changed here.
  Future<AppUser> updateCustomerProfile(
    String userId, {
    String? fullName,
    String? extraContact,
    String? address,
    Gender? gender,
    DateTime? dateOfBirth,
    String? avatarUrl,
  });

  Future<void> changePassword(String userId,
      {required String current, required String next});
  Future<void> setNotificationPrefs(String userId, Map<String, bool> prefs);

  /// Administrator operations (each is audited and permission-checked).
  Future<AppUser> saveUser(AppUser user, {required AppUser actor});
  Future<AppUser> setAccountStatus(String userId, AccountStatus status,
      {required AppUser actor, String? reason});
  Future<AppUser> setCustomerDiscount(String userId, int basisPoints,
      {required AppUser actor});
  Future<AppUser> setManagerAccess(
    String userId, {
    required List<String> studioIds,
    required Set<StaffPermission> permissions,
    required AppUser actor,
  });
  Future<CustomerSummary> customerSummary(String userId);
}
