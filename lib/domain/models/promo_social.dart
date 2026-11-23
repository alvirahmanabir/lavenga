import '../../core/money/money.dart';
import '../enums.dart';
import 'json_helpers.dart';

/// A discount rule. Coupons reference one; automatic discounts (space,
/// category, customer) are applied without a code.
class Discount {
  const Discount({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    required this.scope,
    required this.startsAt,
    required this.endsAt,
    this.targetIds = const [],
    this.minBooking = Money.zero,
    this.maxDiscount,
    this.active = true,
  });

  final String id;
  final String name;
  final DiscountKind kind;

  /// Basis points for percentage (1000 = 10%), minor units for fixed.
  final int value;
  final DiscountScope scope;

  /// Space ids, category ids or customer ids depending on [scope].
  final List<String> targetIds;
  final Money minBooking;
  final Money? maxDiscount;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool active;

  String get valueLabel => kind == DiscountKind.percentage
      ? '${(value / 100).toStringAsFixed(value % 100 == 0 ? 0 : 1)}% off'
      : '${Money.fromMinor(value).format()} off';

  Discount copyWith({
    String? name,
    DiscountKind? kind,
    int? value,
    DiscountScope? scope,
    List<String>? targetIds,
    Money? minBooking,
    Money? maxDiscount,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? active,
  }) =>
      Discount(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        value: value ?? this.value,
        scope: scope ?? this.scope,
        targetIds: targetIds ?? this.targetIds,
        minBooking: minBooking ?? this.minBooking,
        maxDiscount: maxDiscount ?? this.maxDiscount,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'value': value,
        'scope': scope.name,
        'target_ids': targetIds,
        'min_booking_minor': minBooking.minor,
        'max_discount_minor': maxDiscount?.minor,
        'starts_at': dateJson(startsAt),
        'ends_at': dateJson(endsAt),
        'active': active,
      };

  factory Discount.fromJson(Map<String, dynamic> j) => Discount(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: enumFromJson(DiscountKind.values, j['kind'], DiscountKind.percentage),
        value: j['value'] as int,
        scope: enumFromJson(DiscountScope.values, j['scope'], DiscountScope.global),
        targetIds: jStrings(j['target_ids']),
        minBooking: jMoney(j['min_booking_minor']),
        maxDiscount:
            j['max_discount_minor'] == null ? null : jMoney(j['max_discount_minor']),
        startsAt: jDate(j['starts_at']),
        endsAt: jDate(j['ends_at']),
        active: j['active'] as bool? ?? true,
      );
}

class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.discountId,
    this.usageLimit,
    this.perCustomerLimit = 1,
    this.redemptions = const {},
    this.active = true,
  });

  final String id;
  final String code;
  final String discountId;
  final int? usageLimit;
  final int perCustomerLimit;

  /// customerId -> times redeemed.
  final Map<String, int> redemptions;
  final bool active;

  int get usedCount => redemptions.values.fold(0, (a, b) => a + b);
  int usedBy(String customerId) => redemptions[customerId] ?? 0;

  Coupon copyWith({
    String? code,
    int? usageLimit,
    int? perCustomerLimit,
    Map<String, int>? redemptions,
    bool? active,
  }) =>
      Coupon(
        id: id,
        code: code ?? this.code,
        discountId: discountId,
        usageLimit: usageLimit ?? this.usageLimit,
        perCustomerLimit: perCustomerLimit ?? this.perCustomerLimit,
        redemptions: redemptions ?? this.redemptions,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'discount_id': discountId,
        'usage_limit': usageLimit,
        'per_customer_limit': perCustomerLimit,
        'redemptions': redemptions,
        'active': active,
      };

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'] as String,
        code: j['code'] as String,
        discountId: j['discount_id'] as String,
        usageLimit: j['usage_limit'] as int?,
        perCustomerLimit: j['per_customer_limit'] as int? ?? 1,
        redemptions: {
          for (final e in jMap(j['redemptions']).entries) e.key: e.value as int,
        },
        active: j['active'] as bool? ?? true,
      );
}

class CustomerFavorite {
  const CustomerFavorite({
    required this.userId,
    required this.spaceId,
    required this.at,
  });
  final String userId;
  final String spaceId;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'user_id': userId, 'space_id': spaceId, 'at': dateJson(at)};

  factory CustomerFavorite.fromJson(Map<String, dynamic> j) => CustomerFavorite(
        userId: j['user_id'] as String,
        spaceId: j['space_id'] as String,
        at: jDate(j['at']),
      );
}

class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.itemId,
    required this.spaceId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String itemId;
  final String spaceId;
  final String customerId;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'item_id': itemId,
        'space_id': spaceId,
        'customer_id': customerId,
        'customer_name': customerName,
        'rating': rating,
        'comment': comment,
        'created_at': dateJson(createdAt),
      };

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        bookingId: j['booking_id'] as String,
        itemId: j['item_id'] as String,
        spaceId: j['space_id'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String,
        rating: j['rating'] as int,
        comment: j['comment'] as String,
        createdAt: jDate(j['created_at']),
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.at,
  });

  final String id;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String body;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_role': senderRole.name,
        'body': body,
        'at': dateJson(at),
      };

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        senderName: j['sender_name'] as String,
        senderRole:
            enumFromJson(UserRole.values, j['sender_role'], UserRole.customer),
        body: j['body'] as String,
        at: jDate(j['at']),
      );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.customerId,
    required this.customerName,
    required this.category,
    required this.subject,
    required this.status,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.bookingId,
    this.bookingRef,
    this.unreadForCustomer = false,
  });

  final String id;
  final String reference;
  final String customerId;
  final String customerName;
  final String category;
  final String subject;
  final TicketStatus status;
  final List<SupportMessage> messages;
  final String? bookingId;
  final String? bookingRef;
  final bool unreadForCustomer;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket copyWith({
    TicketStatus? status,
    List<SupportMessage>? messages,
    bool? unreadForCustomer,
    DateTime? updatedAt,
  }) =>
      SupportTicket(
        id: id,
        reference: reference,
        customerId: customerId,
        customerName: customerName,
        category: category,
        subject: subject,
        status: status ?? this.status,
        messages: messages ?? this.messages,
        bookingId: bookingId,
        bookingRef: bookingRef,
        unreadForCustomer: unreadForCustomer ?? this.unreadForCustomer,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'customer_id': customerId,
        'customer_name': customerName,
        'category': category,
        'subject': subject,
        'status': status.name,
        'messages': [for (final m in messages) m.toJson()],
        'booking_id': bookingId,
        'booking_ref': bookingRef,
        'unread_for_customer': unreadForCustomer,
        'created_at': dateJson(createdAt),
        'updated_at': dateJson(updatedAt),
      };

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        reference: j['reference'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String,
        category: j['category'] as String,
        subject: j['subject'] as String,
        status: enumFromJson(TicketStatus.values, j['status'], TicketStatus.open),
        messages: [for (final m in jList(j['messages'])) SupportMessage.fromJson(m)],
        bookingId: j['booking_id'] as String?,
        bookingRef: j['booking_ref'] as String?,
        unreadForCustomer: j['unread_for_customer'] as bool? ?? false,
        createdAt: jDate(j['created_at']),
        updatedAt: jDate(j['updated_at']),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.refId,
    this.read = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;

  /// "booking", "refund", "support", "payment" or "offer" (drives deep link).
  final String type;
  final String? refId;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        refId: refId,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'ref_id': refId,
        'read': read,
        'created_at': dateJson(createdAt),
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: j['type'] as String,
        refId: j['ref_id'] as String?,
        read: j['read'] as bool? ?? false,
        createdAt: jDate(j['created_at']),
      );
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.target,
    required this.at,
    this.detail,
    this.sensitive = false,
  });

  final String id;
  final String actorId;
  final String actorName;
  final UserRole actorRole;
  final String action;
  final String target;
  final String? detail;
  final bool sensitive;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'actor_id': actorId,
        'actor_name': actorName,
        'actor_role': actorRole.name,
        'action': action,
        'target': target,
        'detail': detail,
        'sensitive': sensitive,
        'at': dateJson(at),
      };

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'] as String,
        actorId: j['actor_id'] as String,
        actorName: j['actor_name'] as String,
        actorRole: enumFromJson(UserRole.values, j['actor_role'], UserRole.admin),
        action: j['action'] as String,
        target: j['target'] as String,
        detail: j['detail'] as String?,
        sensitive: j['sensitive'] as bool? ?? false,
        at: jDate(j['at']),
      );
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.active = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool active;

  HomeBanner copyWith({String? title, String? subtitle, bool? active}) =>
      HomeBanner(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        imageUrl: imageUrl,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'active': active,
      };

  factory HomeBanner.fromJson(Map<String, dynamic> j) => HomeBanner(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        imageUrl: j['image_url'] as String,
        active: j['active'] as bool? ?? true,
      );
}

/// One cancellation/refund tier: cancelling at least [hoursBefore] hours
/// before the session refunds [refundBp] basis points of the amount paid.
class RefundTier {
  const RefundTier(this.hoursBefore, this.refundBp);
  final int hoursBefore;
  final int refundBp;

  Map<String, dynamic> toJson() => {'hours_before': hoursBefore, 'refund_bp': refundBp};
  factory RefundTier.fromJson(Map<String, dynamic> j) =>
      RefundTier(j['hours_before'] as int, j['refund_bp'] as int);
}

class PlatformSettings {
  const PlatformSettings({
    this.advanceBp = 3000,
    this.holdMinutes = 10,
    this.vatBp = 0,
    this.refundTiers = const [
      RefundTier(72, 10000),
      RefundTier(24, 5000),
      RefundTier(0, 0),
    ],
    this.cancellationPolicy =
        'Pending bookings can be cancelled by you at any time before the studio confirms them. '
            'After confirmation, contact support; the studio team handles cancellations.',
    this.refundPolicy =
        'Refund requests are reviewed by the studio team, then approved by an administrator. '
            'Amounts depend on how far ahead of the session you cancel. Approval is not a promise of timing.',
    this.advancePolicy =
        'Pay the advance now to secure your booking, or pay in full. '
            'The remaining balance can be paid any time before your session.',
    this.terms =
        'By booking you agree to follow each space\'s rules, arrive on time and treat the studio with care. '
            'Damage and overtime may be charged.',
    this.privacy =
        'We store only what we need to run your bookings. We never store card details. '
            'You can ask support to export or delete your data.',
    this.banners = const [],
    this.featuredSpaceIds = const [],
    this.notificationTemplates = const {
      'booking_confirmed': 'Your booking {ref} is confirmed.',
      'payment_received': 'We received your payment of {amount} for {ref}.',
      'refund_update': 'Your refund request for {ref} is now {status}.',
    },
  });

  final int advanceBp;
  final int holdMinutes;
  final int vatBp;
  final List<RefundTier> refundTiers;
  final String cancellationPolicy;
  final String refundPolicy;
  final String advancePolicy;
  final String terms;
  final String privacy;
  final List<HomeBanner> banners;
  final List<String> featuredSpaceIds;
  final Map<String, String> notificationTemplates;

  PlatformSettings copyWith({
    int? advanceBp,
    int? holdMinutes,
    int? vatBp,
    List<RefundTier>? refundTiers,
    String? cancellationPolicy,
    String? refundPolicy,
    String? advancePolicy,
    String? terms,
    String? privacy,
    List<HomeBanner>? banners,
    List<String>? featuredSpaceIds,
    Map<String, String>? notificationTemplates,
  }) =>
      PlatformSettings(
        advanceBp: advanceBp ?? this.advanceBp,
        holdMinutes: holdMinutes ?? this.holdMinutes,
        vatBp: vatBp ?? this.vatBp,
        refundTiers: refundTiers ?? this.refundTiers,
        cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
        refundPolicy: refundPolicy ?? this.refundPolicy,
        advancePolicy: advancePolicy ?? this.advancePolicy,
        terms: terms ?? this.terms,
        privacy: privacy ?? this.privacy,
        banners: banners ?? this.banners,
        featuredSpaceIds: featuredSpaceIds ?? this.featuredSpaceIds,
        notificationTemplates: notificationTemplates ?? this.notificationTemplates,
      );

  Map<String, dynamic> toJson() => {
        'advance_bp': advanceBp,
        'hold_minutes': holdMinutes,
        'vat_bp': vatBp,
        'refund_tiers': [for (final t in refundTiers) t.toJson()],
        'cancellation_policy': cancellationPolicy,
        'refund_policy': refundPolicy,
        'advance_policy': advancePolicy,
        'terms': terms,
        'privacy': privacy,
        'banners': [for (final b in banners) b.toJson()],
        'featured_space_ids': featuredSpaceIds,
        'notification_templates': notificationTemplates,
      };

  factory PlatformSettings.fromJson(Map<String, dynamic> j) {
    const d = PlatformSettings();
    return PlatformSettings(
      advanceBp: j['advance_bp'] as int? ?? d.advanceBp,
      holdMinutes: j['hold_minutes'] as int? ?? d.holdMinutes,
      vatBp: j['vat_bp'] as int? ?? d.vatBp,
      refundTiers: [for (final t in jList(j['refund_tiers'])) RefundTier.fromJson(t)],
      cancellationPolicy: j['cancellation_policy'] as String? ?? d.cancellationPolicy,
      refundPolicy: j['refund_policy'] as String? ?? d.refundPolicy,
      advancePolicy: j['advance_policy'] as String? ?? d.advancePolicy,
      terms: j['terms'] as String? ?? d.terms,
      privacy: j['privacy'] as String? ?? d.privacy,
      banners: [for (final b in jList(j['banners'])) HomeBanner.fromJson(b)],
      featuredSpaceIds: jStrings(j['featured_space_ids']),
      notificationTemplates: {
        for (final e in jMap(j['notification_templates']).entries)
          e.key: e.value as String,
      },
    );
  }
}
