import '../../core/money/money.dart';
import '../enums.dart';
import 'json_helpers.dart';

class BookingSchedule {
  const BookingSchedule({required this.start, required this.end});

  /// UTC instants. Rendered in the studio time zone by the UI.
  final DateTime start;
  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  /// True when the two intervals overlap once [bufferMinutes] of setup and
  /// cleanup time is added around [other].
  bool overlaps(BookingSchedule other, {int bufferMinutes = 0}) {
    final buffer = Duration(minutes: bufferMinutes);
    return start.isBefore(other.end.add(buffer)) &&
        end.add(buffer).isAfter(other.start);
  }

  Map<String, dynamic> toJson() =>
      {'start': dateJson(start), 'end': dateJson(end)};

  factory BookingSchedule.fromJson(Map<String, dynamic> j) =>
      BookingSchedule(start: jDate(j['start']), end: jDate(j['end']));

  @override
  bool operator ==(Object other) =>
      other is BookingSchedule && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// One space reserved for one interval. Copies name, code and rate so later
/// catalogue edits or archiving never change history.
class BookingItem {
  const BookingItem({
    required this.id,
    required this.spaceId,
    required this.spaceCode,
    required this.spaceName,
    required this.studioId,
    required this.studioName,
    required this.schedule,
    required this.hourlyRate,
    this.spaceDiscountBp = 0,
    this.notes = '',
    this.imageUrl,
  });

  final String id;
  final String spaceId;
  final String spaceCode;
  final String spaceName;
  final String studioId;
  final String studioName;
  final BookingSchedule schedule;
  final Money hourlyRate;
  final int spaceDiscountBp;
  final String notes;
  final String? imageUrl;

  BookingItem copyWith({BookingSchedule? schedule, String? notes}) => BookingItem(
        id: id,
        spaceId: spaceId,
        spaceCode: spaceCode,
        spaceName: spaceName,
        studioId: studioId,
        studioName: studioName,
        schedule: schedule ?? this.schedule,
        hourlyRate: hourlyRate,
        spaceDiscountBp: spaceDiscountBp,
        notes: notes ?? this.notes,
        imageUrl: imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'space_id': spaceId,
        'space_code': spaceCode,
        'space_name': spaceName,
        'studio_id': studioId,
        'studio_name': studioName,
        'schedule': schedule.toJson(),
        'hourly_rate_minor': hourlyRate.minor,
        'space_discount_bp': spaceDiscountBp,
        'notes': notes,
        'image_url': imageUrl,
      };

  factory BookingItem.fromJson(Map<String, dynamic> j) => BookingItem(
        id: j['id'] as String,
        spaceId: j['space_id'] as String,
        spaceCode: j['space_code'] as String,
        spaceName: j['space_name'] as String,
        studioId: j['studio_id'] as String,
        studioName: j['studio_name'] as String,
        schedule: BookingSchedule.fromJson(jMap(j['schedule'])),
        hourlyRate: jMoney(j['hourly_rate_minor']),
        spaceDiscountBp: j['space_discount_bp'] as int? ?? 0,
        notes: j['notes'] as String? ?? '',
        imageUrl: j['image_url'] as String?,
      );
}

class PricingLine {
  const PricingLine({
    required this.itemId,
    required this.label,
    required this.minutes,
    required this.gross,
    required this.spaceDiscount,
  });

  final String itemId;
  final String label;
  final int minutes;
  final Money gross;
  final Money spaceDiscount;
  Money get net => gross - spaceDiscount;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'label': label,
        'minutes': minutes,
        'gross_minor': gross.minor,
        'space_discount_minor': spaceDiscount.minor,
      };

  factory PricingLine.fromJson(Map<String, dynamic> j) => PricingLine(
        itemId: j['item_id'] as String,
        label: j['label'] as String,
        minutes: j['minutes'] as int,
        gross: jMoney(j['gross_minor']),
        spaceDiscount: jMoney(j['space_discount_minor']),
      );
}

/// Frozen at order creation. Never recomputed from current catalogue prices.
class BookingPricingSnapshot {
  const BookingPricingSnapshot({
    required this.lines,
    required this.subtotal,
    required this.spaceDiscount,
    required this.customerDiscount,
    required this.couponDiscount,
    required this.fees,
    required this.total,
    required this.advanceRequired,
    this.couponCode,
  });

  final List<PricingLine> lines;

  /// Sum of gross line amounts before any discount.
  final Money subtotal;
  final Money spaceDiscount;
  final Money customerDiscount;
  final Money couponDiscount;
  final String? couponCode;
  final Money fees;
  final Money total;
  final Money advanceRequired;

  Money get totalDiscount => spaceDiscount + customerDiscount + couponDiscount;

  Map<String, dynamic> toJson() => {
        'lines': [for (final l in lines) l.toJson()],
        'subtotal_minor': subtotal.minor,
        'space_discount_minor': spaceDiscount.minor,
        'customer_discount_minor': customerDiscount.minor,
        'coupon_discount_minor': couponDiscount.minor,
        'coupon_code': couponCode,
        'fees_minor': fees.minor,
        'total_minor': total.minor,
        'advance_minor': advanceRequired.minor,
      };

  factory BookingPricingSnapshot.fromJson(Map<String, dynamic> j) =>
      BookingPricingSnapshot(
        lines: [for (final l in jList(j['lines'])) PricingLine.fromJson(l)],
        subtotal: jMoney(j['subtotal_minor']),
        spaceDiscount: jMoney(j['space_discount_minor']),
        customerDiscount: jMoney(j['customer_discount_minor']),
        couponDiscount: jMoney(j['coupon_discount_minor']),
        couponCode: j['coupon_code'] as String?,
        fees: jMoney(j['fees_minor']),
        total: jMoney(j['total_minor']),
        advanceRequired: jMoney(j['advance_minor']),
      );
}

class TimelineEvent {
  const TimelineEvent({
    required this.at,
    required this.title,
    required this.actor,
    this.note,
  });

  final DateTime at;
  final String title;
  final String actor;
  final String? note;

  Map<String, dynamic> toJson() =>
      {'at': dateJson(at), 'title': title, 'actor': actor, 'note': note};

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        at: jDate(j['at']),
        title: j['title'] as String,
        actor: j['actor'] as String,
        note: j['note'] as String?,
      );
}

class InternalNote {
  const InternalNote({
    required this.id,
    required this.authorName,
    required this.text,
    required this.at,
  });

  final String id;
  final String authorName;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'id': id, 'author_name': authorName, 'text': text, 'at': dateJson(at)};

  factory InternalNote.fromJson(Map<String, dynamic> j) => InternalNote(
        id: j['id'] as String,
        authorName: j['author_name'] as String,
        text: j['text'] as String,
        at: jDate(j['at']),
      );
}

/// An order: one checkout holding one or more booking items.
class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.pricing,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.internalNotes = const [],
    this.timeline = const [],
    this.holdExpiresAt,
    this.cancelReason,
  });

  final String id;
  final String reference;
  final String customerId;
  final String customerName;
  final List<BookingItem> items;
  final BookingPricingSnapshot pricing;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String notes;
  final List<InternalNote> internalNotes;
  final List<TimelineEvent> timeline;

  /// While set and in the future, the slots are held for an unpaid order.
  final DateTime? holdExpiresAt;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Money get total => pricing.total;
  DateTime get firstStart => items
      .map((i) => i.schedule.start)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get lastEnd =>
      items.map((i) => i.schedule.end).reduce((a, b) => a.isAfter(b) ? a : b);
  Set<String> get studioIds => {for (final i in items) i.studioId};

  Booking copyWith({
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    List<BookingItem>? items,
    BookingPricingSnapshot? pricing,
    List<InternalNote>? internalNotes,
    List<TimelineEvent>? timeline,
    DateTime? holdExpiresAt,
    bool clearHold = false,
    String? cancelReason,
    DateTime? updatedAt,
  }) =>
      Booking(
        id: id,
        reference: reference,
        customerId: customerId,
        customerName: customerName,
        items: items ?? this.items,
        pricing: pricing ?? this.pricing,
        status: status ?? this.status,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        notes: notes,
        internalNotes: internalNotes ?? this.internalNotes,
        timeline: timeline ?? this.timeline,
        holdExpiresAt: clearHold ? null : (holdExpiresAt ?? this.holdExpiresAt),
        cancelReason: cancelReason ?? this.cancelReason,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'customer_id': customerId,
        'customer_name': customerName,
        'items': [for (final i in items) i.toJson()],
        'pricing': pricing.toJson(),
        'status': status.name,
        'payment_status': paymentStatus.name,
        'notes': notes,
        'internal_notes': [for (final n in internalNotes) n.toJson()],
        'timeline': [for (final t in timeline) t.toJson()],
        'hold_expires_at': dateJson(holdExpiresAt),
        'cancel_reason': cancelReason,
        'created_at': dateJson(createdAt),
        'updated_at': dateJson(updatedAt),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        reference: j['reference'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String,
        items: [for (final i in jList(j['items'])) BookingItem.fromJson(i)],
        pricing: BookingPricingSnapshot.fromJson(jMap(j['pricing'])),
        status: enumFromJson(BookingStatus.values, j['status'], BookingStatus.pendingReview),
        paymentStatus:
            enumFromJson(PaymentStatus.values, j['payment_status'], PaymentStatus.unpaid),
        notes: j['notes'] as String? ?? '',
        internalNotes: [
          for (final n in jList(j['internal_notes'])) InternalNote.fromJson(n)
        ],
        timeline: [for (final t in jList(j['timeline'])) TimelineEvent.fromJson(t)],
        holdExpiresAt: jDateOpt(j['hold_expires_at']),
        cancelReason: j['cancel_reason'] as String?,
        createdAt: jDate(j['created_at']),
        updatedAt: jDate(j['updated_at']),
      );
}
