import '../../core/money/money.dart';
import '../enums.dart';
import 'json_helpers.dart';

class Studio {
  const Studio({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.area,
    required this.city,
    required this.imageUrl,
    required this.createdAt,
    this.archived = false,
    this.utcOffsetMinutes = 360,
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final String area;
  final String city;
  final String imageUrl;
  final DateTime createdAt;
  final bool archived;

  /// Studio time zone as a fixed offset (Asia/Dhaka, no DST). The UI formats
  /// all schedules in this zone; storage is always UTC.
  final int utcOffsetMinutes;

  String get location => '$area, $city';

  Studio copyWith({
    String? name,
    String? description,
    String? address,
    String? area,
    String? city,
    String? imageUrl,
    bool? archived,
  }) =>
      Studio(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        address: address ?? this.address,
        area: area ?? this.area,
        city: city ?? this.city,
        imageUrl: imageUrl ?? this.imageUrl,
        createdAt: createdAt,
        archived: archived ?? this.archived,
        utcOffsetMinutes: utcOffsetMinutes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'address': address,
        'area': area,
        'city': city,
        'image_url': imageUrl,
        'created_at': dateJson(createdAt),
        'archived': archived,
        'utc_offset_minutes': utcOffsetMinutes,
      };

  factory Studio.fromJson(Map<String, dynamic> j) => Studio(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        address: j['address'] as String,
        area: j['area'] as String,
        city: j['city'] as String,
        imageUrl: j['image_url'] as String,
        createdAt: jDate(j['created_at']),
        archived: j['archived'] as bool? ?? false,
        utcOffsetMinutes: j['utc_offset_minutes'] as int? ?? 360,
      );
}

class SpaceCategory {
  const SpaceCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.active = true,
  });

  final String id;
  final String name;

  /// Key into the UI icon map (e.g. "camera", "mic").
  final String icon;
  final bool active;

  SpaceCategory copyWith({String? name, String? icon, bool? active}) =>
      SpaceCategory(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'icon': icon, 'active': active};

  factory SpaceCategory.fromJson(Map<String, dynamic> j) => SpaceCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        active: j['active'] as bool? ?? true,
      );
}

/// Weekly operating window in studio-local minutes since midnight.
class OperatingHours {
  const OperatingHours({
    required this.openMinute,
    required this.closeMinute,
    this.closedWeekdays = const [],
  });

  final int openMinute;
  final int closeMinute;

  /// DateTime.weekday values (1 = Monday ... 7 = Sunday).
  final List<int> closedWeekdays;

  bool isOpenOn(int weekday) => !closedWeekdays.contains(weekday);

  String get label =>
      '${_fmt(openMinute)} – ${_fmt(closeMinute)}';

  static String _fmt(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    final period = h >= 12 && h < 24 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  OperatingHours copyWith({
    int? openMinute,
    int? closeMinute,
    List<int>? closedWeekdays,
  }) =>
      OperatingHours(
        openMinute: openMinute ?? this.openMinute,
        closeMinute: closeMinute ?? this.closeMinute,
        closedWeekdays: closedWeekdays ?? this.closedWeekdays,
      );

  Map<String, dynamic> toJson() => {
        'open_minute': openMinute,
        'close_minute': closeMinute,
        'closed_weekdays': closedWeekdays,
      };

  factory OperatingHours.fromJson(Map<String, dynamic> j) => OperatingHours(
        openMinute: j['open_minute'] as int,
        closeMinute: j['close_minute'] as int,
        closedWeekdays: [for (final d in (j['closed_weekdays'] as List)) d as int],
      );
}

class StudioSpace {
  const StudioSpace({
    required this.id,
    required this.code,
    required this.studioId,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.images,
    required this.facilities,
    required this.equipment,
    required this.rules,
    required this.capacity,
    required this.dimensions,
    required this.hourlyRate,
    required this.hours,
    required this.createdAt,
    this.videoUrl,
    this.discountBp = 0,
    this.minMinutes = 60,
    this.maxMinutes = 480,
    this.bufferMinutes = 30,
    this.status = SpaceStatus.active,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.popularity = 0,
  });

  final String id;

  /// Unique, human-readable code shown to customers (e.g. "LV-CYC-01").
  final String code;
  final String studioId;
  final String name;
  final String categoryId;
  final String description;
  final List<String> images;
  final String? videoUrl;
  final List<String> facilities;
  final List<String> equipment;
  final List<String> rules;
  final int capacity;
  final String dimensions;
  final Money hourlyRate;

  /// Space-level discount in basis points (1500 = 15%). 0 = none.
  final int discountBp;
  final OperatingHours hours;
  final int minMinutes;
  final int maxMinutes;
  final int bufferMinutes;
  final SpaceStatus status;
  final double ratingAvg;
  final int ratingCount;
  final int popularity;
  final DateTime createdAt;

  bool get isBookable => status == SpaceStatus.active;
  bool get hasDiscount => discountBp > 0;
  Money get discountedRate => hourlyRate - hourlyRate.percent(discountBp);

  StudioSpace copyWith({
    String? code,
    String? name,
    String? categoryId,
    String? description,
    List<String>? images,
    List<String>? facilities,
    List<String>? equipment,
    List<String>? rules,
    int? capacity,
    String? dimensions,
    Money? hourlyRate,
    int? discountBp,
    OperatingHours? hours,
    int? minMinutes,
    int? maxMinutes,
    int? bufferMinutes,
    SpaceStatus? status,
    double? ratingAvg,
    int? ratingCount,
    int? popularity,
  }) =>
      StudioSpace(
        id: id,
        code: code ?? this.code,
        studioId: studioId,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        description: description ?? this.description,
        images: images ?? this.images,
        videoUrl: videoUrl,
        facilities: facilities ?? this.facilities,
        equipment: equipment ?? this.equipment,
        rules: rules ?? this.rules,
        capacity: capacity ?? this.capacity,
        dimensions: dimensions ?? this.dimensions,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        discountBp: discountBp ?? this.discountBp,
        hours: hours ?? this.hours,
        minMinutes: minMinutes ?? this.minMinutes,
        maxMinutes: maxMinutes ?? this.maxMinutes,
        bufferMinutes: bufferMinutes ?? this.bufferMinutes,
        status: status ?? this.status,
        ratingAvg: ratingAvg ?? this.ratingAvg,
        ratingCount: ratingCount ?? this.ratingCount,
        popularity: popularity ?? this.popularity,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'studio_id': studioId,
        'name': name,
        'category_id': categoryId,
        'description': description,
        'images': images,
        'video_url': videoUrl,
        'facilities': facilities,
        'equipment': equipment,
        'rules': rules,
        'capacity': capacity,
        'dimensions': dimensions,
        'hourly_rate_minor': hourlyRate.minor,
        'discount_bp': discountBp,
        'hours': hours.toJson(),
        'min_minutes': minMinutes,
        'max_minutes': maxMinutes,
        'buffer_minutes': bufferMinutes,
        'status': status.name,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'popularity': popularity,
        'created_at': dateJson(createdAt),
      };

  factory StudioSpace.fromJson(Map<String, dynamic> j) => StudioSpace(
        id: j['id'] as String,
        code: j['code'] as String,
        studioId: j['studio_id'] as String,
        name: j['name'] as String,
        categoryId: j['category_id'] as String,
        description: j['description'] as String,
        images: jStrings(j['images']),
        videoUrl: j['video_url'] as String?,
        facilities: jStrings(j['facilities']),
        equipment: jStrings(j['equipment']),
        rules: jStrings(j['rules']),
        capacity: j['capacity'] as int,
        dimensions: j['dimensions'] as String,
        hourlyRate: Money.fromMinor(j['hourly_rate_minor'] as int),
        discountBp: j['discount_bp'] as int? ?? 0,
        hours: OperatingHours.fromJson(jMap(j['hours'])),
        minMinutes: j['min_minutes'] as int,
        maxMinutes: j['max_minutes'] as int,
        bufferMinutes: j['buffer_minutes'] as int,
        status: enumFromJson(SpaceStatus.values, j['status'], SpaceStatus.active),
        ratingAvg: (j['rating_avg'] as num? ?? 0).toDouble(),
        ratingCount: j['rating_count'] as int? ?? 0,
        popularity: j['popularity'] as int? ?? 0,
        createdAt: jDate(j['created_at']),
      );
}

/// A blocked period (maintenance, private use) on a space's calendar.
class SpaceAvailability {
  const SpaceAvailability({
    required this.id,
    required this.spaceId,
    required this.start,
    required this.end,
    required this.reason,
  });

  final String id;
  final String spaceId;
  final DateTime start;
  final DateTime end;
  final String reason;

  Map<String, dynamic> toJson() => {
        'id': id,
        'space_id': spaceId,
        'start': dateJson(start),
        'end': dateJson(end),
        'reason': reason,
      };

  factory SpaceAvailability.fromJson(Map<String, dynamic> j) =>
      SpaceAvailability(
        id: j['id'] as String,
        spaceId: j['space_id'] as String,
        start: jDate(j['start']),
        end: jDate(j['end']),
        reason: j['reason'] as String,
      );
}
