import 'dart:convert';

import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../local/local_store.dart';
import 'seed_data.dart';

/// In-memory "server" state, persisted locally so demo changes survive app
/// restarts. Mock repositories read and mutate this; the UI never touches it.
class MockDatabase {
  MockDatabase(this.store);

  static const _storageKey = 'lavenga_mock_db_v1';

  final LocalStore store;

  List<AppUser> users = [];
  List<Studio> studios = [];
  List<SpaceCategory> categories = [];
  List<StudioSpace> spaces = [];
  List<SpaceAvailability> blocks = [];
  List<Booking> bookings = [];
  List<Payment> payments = [];
  List<RefundRequest> refunds = [];
  List<Discount> discounts = [];
  List<Coupon> coupons = [];
  List<CustomerFavorite> favorites = [];
  Map<String, List<String>> viewed = {};
  List<Review> reviews = [];
  List<SupportTicket> tickets = [];
  List<AppNotification> notifications = [];
  List<AuditLog> audit = [];
  PlatformSettings settings = const PlatformSettings();
  int counter = 1000;
  String? sessionUserId;

  /// Opens persisted state, or seeds fresh demo data relative to [now].
  static Future<MockDatabase> open(LocalStore store, DateTime now) async {
    final db = MockDatabase(store);
    final raw = store.read(_storageKey);
    if (raw != null) {
      try {
        db._load(jsonDecode(raw) as Map<String, dynamic>);
        return db;
      } catch (_) {
        // Corrupt or older schema: fall through and reseed.
      }
    }
    seedDatabase(db, now);
    db.persist();
    return db;
  }

  /// Fresh seeded database that is not read from storage (tests, reset).
  static MockDatabase seeded(LocalStore store, DateTime now) {
    final db = MockDatabase(store);
    seedDatabase(db, now);
    return db;
  }

  void reset(DateTime now) {
    users = [];
    studios = [];
    categories = [];
    spaces = [];
    blocks = [];
    bookings = [];
    payments = [];
    refunds = [];
    discounts = [];
    coupons = [];
    favorites = [];
    viewed = {};
    reviews = [];
    tickets = [];
    notifications = [];
    audit = [];
    settings = const PlatformSettings();
    counter = 1000;
    sessionUserId = null;
    seedDatabase(this, now);
    persist();
  }

  String newId(String prefix) => '${prefix}_${counter++}';

  void persist() {
    store.write(_storageKey, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'users': [for (final x in users) x.toJson()],
        'studios': [for (final x in studios) x.toJson()],
        'categories': [for (final x in categories) x.toJson()],
        'spaces': [for (final x in spaces) x.toJson()],
        'blocks': [for (final x in blocks) x.toJson()],
        'bookings': [for (final x in bookings) x.toJson()],
        'payments': [for (final x in payments) x.toJson()],
        'refunds': [for (final x in refunds) x.toJson()],
        'discounts': [for (final x in discounts) x.toJson()],
        'coupons': [for (final x in coupons) x.toJson()],
        'favorites': [for (final x in favorites) x.toJson()],
        'viewed': viewed,
        'reviews': [for (final x in reviews) x.toJson()],
        'tickets': [for (final x in tickets) x.toJson()],
        'notifications': [for (final x in notifications) x.toJson()],
        'audit': [for (final x in audit) x.toJson()],
        'settings': settings.toJson(),
        'counter': counter,
        'session_user_id': sessionUserId,
      };

  List<Map<String, dynamic>> _list(Map<String, dynamic> j, String key) => [
        for (final e in (j[key] as List? ?? const [])) Map<String, dynamic>.from(e as Map),
      ];

  void _load(Map<String, dynamic> j) {
    users = [for (final m in _list(j, 'users')) AppUser.fromJson(m)];
    studios = [for (final m in _list(j, 'studios')) Studio.fromJson(m)];
    categories = [for (final m in _list(j, 'categories')) SpaceCategory.fromJson(m)];
    spaces = [for (final m in _list(j, 'spaces')) StudioSpace.fromJson(m)];
    blocks = [for (final m in _list(j, 'blocks')) SpaceAvailability.fromJson(m)];
    bookings = [for (final m in _list(j, 'bookings')) Booking.fromJson(m)];
    payments = [for (final m in _list(j, 'payments')) Payment.fromJson(m)];
    refunds = [for (final m in _list(j, 'refunds')) RefundRequest.fromJson(m)];
    discounts = [for (final m in _list(j, 'discounts')) Discount.fromJson(m)];
    coupons = [for (final m in _list(j, 'coupons')) Coupon.fromJson(m)];
    favorites = [for (final m in _list(j, 'favorites')) CustomerFavorite.fromJson(m)];
    viewed = {
      for (final e in (j['viewed'] as Map? ?? const {}).entries)
        e.key as String: [for (final id in e.value as List) id as String],
    };
    reviews = [for (final m in _list(j, 'reviews')) Review.fromJson(m)];
    tickets = [for (final m in _list(j, 'tickets')) SupportTicket.fromJson(m)];
    notifications = [for (final m in _list(j, 'notifications')) AppNotification.fromJson(m)];
    audit = [for (final m in _list(j, 'audit')) AuditLog.fromJson(m)];
    settings = PlatformSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map));
    if (settings.refundTiers.isEmpty) settings = const PlatformSettings().copyWith(
      advanceBp: settings.advanceBp,
      holdMinutes: settings.holdMinutes,
      vatBp: settings.vatBp,
      banners: settings.banners,
      featuredSpaceIds: settings.featuredSpaceIds,
    );
    counter = j['counter'] as int? ?? 1000;
    sessionUserId = j['session_user_id'] as String?;
    if (users.isEmpty || spaces.isEmpty) throw const FormatException('empty db');
  }
}
