import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../domain/enums.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/account_repositories.dart';
import '../../domain/services/payment_calculator.dart';
import 'mock_context.dart';
import '../../core/config/auth_config.dart';
import 'seed_data.dart' show demoOtp;

String _normalizePhone(String v) => v.replaceAll(RegExp(r'[\s\-()]'), '');

class MockAuthRepository extends MockRepo implements AuthRepository {
  MockAuthRepository(super.ctx);

  AppUser? _find(String identifier) {
    final id = identifier.trim();
    final lower = id.toLowerCase();
    final phone = _normalizePhone(id);
    for (final u in db.users) {
      if (u.email?.toLowerCase() == lower) return u;
      if (u.phone != null && _normalizePhone(u.phone!) == phone) return u;
    }
    return null;
  }

  @override
  Future<AppUser?> restoreSession() async {
    final id = db.sessionUserId;
    if (id == null) return null;
    for (final u in db.users) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<AppUser> signIn({required String identifier, required String password}) async {
    await wait();
    final user = _find(identifier);
    if (user == null || user.password != password) {
      throw const ValidationFailure('Incorrect email, phone or password');
    }
    final updated = user.copyWith(lastLoginAt: now);
    db.users[db.users.indexWhere((u) => u.id == user.id)] = updated;
    if (updated.verified) {
      db.sessionUserId = updated.id;
      audit(updated, 'login', 'Session');
    }
    commit();
    return updated;
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
  }) async {
    await wait();
    if ((email == null || email.trim().isEmpty) && (phone == null || phone.trim().isEmpty)) {
      throw const ValidationFailure('Enter an email or a phone number');
    }
    final emailValue = email?.trim();
    final phoneValue = phone == null ? null : _normalizePhone(phone);
    if (emailValue != null && emailValue.isNotEmpty && _find(emailValue) != null) {
      throw const ValidationFailure('An account with this email already exists', field: 'email');
    }
    if (phoneValue != null && phoneValue.isNotEmpty && _find(phoneValue) != null) {
      throw const ValidationFailure('An account with this phone number already exists', field: 'phone');
    }
    final user = AppUser(
      id: db.newId('u'),
      role: UserRole.customer,
      fullName: fullName.trim(),
      email: (emailValue?.isEmpty ?? true) ? null : emailValue,
      phone: (phoneValue?.isEmpty ?? true) ? null : phoneValue,
      password: password,
      verified: !AuthConfig.requireEmailVerification,
      createdAt: now,
      customer: const CustomerProfile(),
    );
    db.users.add(user);
    commit();
    return user;
  }

  @override
  Future<AppUser> verifyOtp({required String userId, required String code}) async {
    await wait();
    if (code.trim() != demoOtp) {
      throw const ValidationFailure('That code is incorrect. Please try again.');
    }
    final user = userById(userId);
    final updated = user.copyWith(verified: true, lastLoginAt: now);
    db.users[db.users.indexWhere((u) => u.id == userId)] = updated;
    db.sessionUserId = userId;
    audit(updated, 'login', 'Session');
    commit();
    return updated;
  }

  @override
  Future<void> resendOtp(String userId) async {
    await wait();
    userById(userId);
  }

  @override
  Future<String> requestPasswordReset(String identifier) async {
    await wait();
    final user = _find(identifier);
    if (user == null) throw const ValidationFailure('We could not find an account with that email or phone');
    return user.id;
  }

  @override
  Future<void> resetPassword({
    required String userId,
    required String code,
    required String newPassword,
  }) async {
    await wait();
    if (code.trim() != demoOtp) {
      throw const ValidationFailure('That code is incorrect. Please try again.');
    }
    final user = userById(userId);
    db.users[db.users.indexWhere((u) => u.id == userId)] = user.copyWith(password: newPassword);
    commit();
  }

  @override
  Future<void> signOut() async {
    db.sessionUserId = null;
    commit();
  }
}

class MockUserRepository extends MockRepo implements UserRepository {
  MockUserRepository(super.ctx);

  @override
  Future<AppUser> getUser(String id) async => userById(id);

  @override
  Future<List<AppUser>> listUsers({UserRole? role, String? query}) async {
    final q = (query ?? '').trim().toLowerCase();
    final list = db.users.where((u) {
      if (role != null && u.role != role) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          (u.phone ?? '').contains(q);
    }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  void _put(AppUser u) {
    final i = db.users.indexWhere((x) => x.id == u.id);
    if (i < 0) {
      db.users.add(u);
    } else {
      db.users[i] = u;
    }
  }

  @override
  Future<AppUser> updateCustomerProfile(
    String userId, {
    String? fullName,
    String? extraContact,
    String? address,
    Gender? gender,
    DateTime? dateOfBirth,
    String? avatarUrl,
  }) async {
    await wait();
    final user = userById(userId);
    if (fullName != null && fullName.trim().isEmpty) {
      throw const ValidationFailure('Name cannot be empty', field: 'name');
    }
    // Registered email and phone are intentionally not editable here.
    final profile = (user.customer ?? const CustomerProfile()).copyWith(
      extraContact: extraContact,
      address: address,
      gender: gender,
      dateOfBirth: dateOfBirth,
      avatarUrl: avatarUrl,
    );
    final updated = user.copyWith(fullName: fullName?.trim(), customer: profile);
    _put(updated);
    commit();
    return updated;
  }

  @override
  Future<void> changePassword(String userId,
      {required String current, required String next}) async {
    await wait();
    final user = userById(userId);
    if (user.password != current) {
      throw const ValidationFailure('Current password is incorrect', field: 'current');
    }
    if (next.length < 8) {
      throw const ValidationFailure('Use at least 8 characters', field: 'next');
    }
    _put(user.copyWith(password: next));
    commit();
  }

  @override
  Future<void> setNotificationPrefs(String userId, Map<String, bool> prefs) async {
    final user = userById(userId);
    _put(user.copyWith(notificationPrefs: prefs));
    commit();
  }

  @override
  Future<AppUser> saveUser(AppUser user, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (user.fullName.trim().isEmpty) throw const ValidationFailure('Name is required');
    for (final other in db.users) {
      if (other.id == user.id) continue;
      if (user.email != null && other.email?.toLowerCase() == user.email!.toLowerCase()) {
        throw const ValidationFailure('That email is already in use', field: 'email');
      }
      if (user.phone != null && other.phone == user.phone) {
        throw const ValidationFailure('That phone number is already in use', field: 'phone');
      }
    }
    final isNew = !db.users.any((u) => u.id == user.id);
    final saved = isNew
        ? AppUser(
            id: db.newId('u'),
            role: user.role,
            fullName: user.fullName,
            email: user.email,
            phone: user.phone,
            password: user.password.isEmpty ? 'Lavenga@123' : user.password,
            status: user.status,
            verified: true,
            customer: user.customer,
            manager: user.manager,
            createdAt: now,
          )
        : user;
    _put(saved);
    audit(actor, isNew ? 'Created ${saved.role.label.toLowerCase()}' : 'Updated ${saved.role.label.toLowerCase()}',
        saved.fullName,
        sensitive: saved.isManager);
    commit();
    return saved;
  }

  @override
  Future<AppUser> setAccountStatus(String userId, AccountStatus status,
      {required AppUser actor, String? reason}) async {
    await wait();
    requireAdmin(actor);
    final user = userById(userId);
    if (user.id == actor.id) throw const ValidationFailure('You cannot restrict your own account');
    if (status == AccountStatus.blacklisted && (reason == null || reason.trim().isEmpty)) {
      throw const ValidationFailure('A reason is required to blacklist a customer');
    }
    var updated = user.copyWith(status: status);
    if (user.isCustomer) {
      final profile = user.customer ?? const CustomerProfile();
      updated = updated.copyWith(
        customer: status == AccountStatus.blacklisted
            ? profile.copyWith(blacklistReason: reason!.trim())
            : profile.copyWith(clearBlacklistReason: true),
      );
    }
    _put(updated);
    audit(actor, switch (status) {
      AccountStatus.blacklisted => 'Blacklisted customer',
      AccountStatus.active => 'Restored account',
      AccountStatus.suspended => 'Suspended account',
      AccountStatus.deactivated => 'Deactivated account',
    }, user.fullName, detail: reason, sensitive: true);
    commit();
    return updated;
  }

  @override
  Future<AppUser> setCustomerDiscount(String userId, int basisPoints,
      {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (basisPoints < 0 || basisPoints > 5000) {
      throw const ValidationFailure('Discount must be between 0% and 50%');
    }
    final user = userById(userId);
    final updated = user.copyWith(
      customer: (user.customer ?? const CustomerProfile()).copyWith(discountBp: basisPoints),
    );
    _put(updated);
    audit(actor, 'Set customer discount', user.fullName,
        detail: '${(basisPoints / 100).toStringAsFixed(basisPoints % 100 == 0 ? 0 : 1)}%');
    commit();
    return updated;
  }

  @override
  Future<AppUser> setManagerAccess(
    String userId, {
    required List<String> studioIds,
    required Set<StaffPermission> permissions,
    required AppUser actor,
  }) async {
    await wait();
    requireAdmin(actor);
    if (userId == actor.id) throw const Forbidden('cannot edit own access');
    final user = userById(userId);
    final updated = user.copyWith(
      manager: ManagerProfile(studioIds: studioIds, permissions: permissions),
    );
    _put(updated);
    audit(actor, 'Changed manager permissions', user.fullName,
        detail: '${permissions.length} permissions, ${studioIds.length} studios', sensitive: true);
    commit();
    return updated;
  }

  @override
  Future<CustomerSummary> customerSummary(String userId) async {
    sweepHolds();
    final bookings = db.bookings.where((b) => b.customerId == userId).toList();
    var paid = Money.zero;
    var refunded = Money.zero;
    var outstanding = Money.zero;
    for (final b in bookings) {
      final pays = paymentsOf(b.id);
      paid += PaymentCalculator.verifiedPaid(pays);
      refunded += refundedOf(b.id);
      if (b.status != BookingStatus.cancelled &&
          b.status != BookingStatus.rejected &&
          b.status != BookingStatus.expired) {
        outstanding += PaymentCalculator.remainingDue(b.total, pays);
      }
    }
    return CustomerSummary(
      bookings: bookings.length,
      lifetimeSpend: (paid - refunded).clampMin(Money.zero),
      refunded: refunded,
      outstanding: outstanding,
      reviews: db.reviews.where((r) => r.customerId == userId).length,
      tickets: db.tickets.where((t) => t.customerId == userId).length,
    );
  }
}
