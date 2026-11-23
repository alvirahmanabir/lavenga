import '../enums.dart';
import 'json_helpers.dart';

class CustomerProfile {
  const CustomerProfile({
    this.extraContact,
    this.address,
    this.gender,
    this.dateOfBirth,
    this.avatarUrl,
    this.discountBp = 0,
    this.blacklistReason,
  });

  /// Additional contact number. Registered email/phone live on [AppUser]
  /// and are read-only in the profile form.
  final String? extraContact;
  final String? address;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final String? avatarUrl;

  /// Customer-specific discount in basis points, set by an administrator.
  final int discountBp;
  final String? blacklistReason;

  CustomerProfile copyWith({
    String? extraContact,
    String? address,
    Gender? gender,
    DateTime? dateOfBirth,
    String? avatarUrl,
    int? discountBp,
    String? blacklistReason,
    bool clearBlacklistReason = false,
  }) =>
      CustomerProfile(
        extraContact: extraContact ?? this.extraContact,
        address: address ?? this.address,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        discountBp: discountBp ?? this.discountBp,
        blacklistReason: clearBlacklistReason
            ? null
            : (blacklistReason ?? this.blacklistReason),
      );

  Map<String, dynamic> toJson() => {
        'extra_contact': extraContact,
        'address': address,
        'gender': gender?.name,
        'date_of_birth': dateJson(dateOfBirth),
        'avatar_url': avatarUrl,
        'discount_bp': discountBp,
        'blacklist_reason': blacklistReason,
      };

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
        extraContact: j['extra_contact'] as String?,
        address: j['address'] as String?,
        gender: j['gender'] == null
            ? null
            : enumFromJson(Gender.values, j['gender'], Gender.other),
        dateOfBirth: jDateOpt(j['date_of_birth']),
        avatarUrl: j['avatar_url'] as String?,
        discountBp: j['discount_bp'] as int? ?? 0,
        blacklistReason: j['blacklist_reason'] as String?,
      );
}

class ManagerProfile {
  const ManagerProfile({
    this.studioIds = const [],
    this.permissions = const {},
  });

  /// Studios this manager may operate. Every manager query filters by this.
  final List<String> studioIds;
  final Set<StaffPermission> permissions;

  ManagerProfile copyWith({
    List<String>? studioIds,
    Set<StaffPermission>? permissions,
  }) =>
      ManagerProfile(
        studioIds: studioIds ?? this.studioIds,
        permissions: permissions ?? this.permissions,
      );

  Map<String, dynamic> toJson() => {
        'studio_ids': studioIds,
        'permissions': [for (final p in permissions) p.name],
      };

  factory ManagerProfile.fromJson(Map<String, dynamic> j) => ManagerProfile(
        studioIds: jStrings(j['studio_ids']),
        permissions: {
          for (final p in jStrings(j['permissions']))
            enumFromJson(StaffPermission.values, p, StaffPermission.viewReports),
        },
      );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullName,
    required this.createdAt,
    this.email,
    this.phone,
    this.password = '',
    this.status = AccountStatus.active,
    this.verified = true,
    this.customer,
    this.manager,
    this.lastLoginAt,
    this.notificationPrefs = const {
      'bookings': true,
      'payments': true,
      'offers': false,
      'support': true,
    },
  });

  final String id;
  final UserRole role;
  final String fullName;

  /// Registered login identities. Read-only for customers.
  final String? email;
  final String? phone;

  /// MOCK ONLY. Real credentials live in Supabase Auth, never in the client.
  final String password;
  final AccountStatus status;
  final bool verified;
  final CustomerProfile? customer;
  final ManagerProfile? manager;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, bool> notificationPrefs;

  bool get isCustomer => role == UserRole.customer;
  bool get isManager => role == UserRole.manager;
  bool get isAdmin => role == UserRole.admin;
  bool get isRestricted =>
      status == AccountStatus.blacklisted ||
      status == AccountStatus.suspended ||
      status == AccountStatus.deactivated;
  String get identity => email ?? phone ?? id;
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '?' : parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? password,
    AccountStatus? status,
    bool? verified,
    CustomerProfile? customer,
    ManagerProfile? manager,
    DateTime? lastLoginAt,
    Map<String, bool>? notificationPrefs,
  }) =>
      AppUser(
        id: id,
        role: role,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        password: password ?? this.password,
        status: status ?? this.status,
        verified: verified ?? this.verified,
        customer: customer ?? this.customer,
        manager: manager ?? this.manager,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'status': status.name,
        'verified': verified,
        'customer': customer?.toJson(),
        'manager': manager?.toJson(),
        'created_at': dateJson(createdAt),
        'last_login_at': dateJson(lastLoginAt),
        'notification_prefs': notificationPrefs,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        role: enumFromJson(UserRole.values, j['role'], UserRole.customer),
        fullName: j['full_name'] as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        password: j['password'] as String? ?? '',
        status: enumFromJson(AccountStatus.values, j['status'], AccountStatus.active),
        verified: j['verified'] as bool? ?? true,
        customer: j['customer'] == null
            ? null
            : CustomerProfile.fromJson(jMap(j['customer'])),
        manager: j['manager'] == null
            ? null
            : ManagerProfile.fromJson(jMap(j['manager'])),
        createdAt: jDate(j['created_at']),
        lastLoginAt: jDateOpt(j['last_login_at']),
        notificationPrefs: {
          for (final e in jMap(j['notification_prefs']).entries)
            e.key: e.value as bool,
        },
      );
}
