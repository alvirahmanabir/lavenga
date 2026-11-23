import '../../core/money/money.dart';
import '../enums.dart';
import '../models/catalogue.dart';
import '../models/user.dart';
import '../services/availability_service.dart';

class SpaceQuery {
  const SpaceQuery({
    this.text = '',
    this.categoryId,
    this.studioId,
    this.studioIds,
    this.minPrice,
    this.maxPrice,
    this.date,
    this.startMinute,
    this.minRating = 0,
    this.minCapacity,
    this.facilities = const {},
    this.equipment = const {},
    this.discountOnly = false,
    this.sort = SpaceSort.recommended,
    this.includeInactive = false,
  });

  /// Matches studio name, space name, code, category, keywords and location.
  final String text;
  final String? categoryId;
  final String? studioId;

  /// Manager scope; null means no restriction.
  final List<String>? studioIds;
  final Money? minPrice;
  final Money? maxPrice;

  /// Studio-local day start (UTC instant) and optional start minute: only
  /// spaces free for their minimum duration then are returned.
  final DateTime? date;
  final int? startMinute;
  final double minRating;
  final int? minCapacity;
  final Set<String> facilities;
  final Set<String> equipment;
  final bool discountOnly;
  final SpaceSort sort;
  final bool includeInactive;

  int get activeFilterCount => [
        categoryId != null,
        minPrice != null || maxPrice != null,
        date != null,
        minRating > 0,
        minCapacity != null,
        facilities.isNotEmpty,
        equipment.isNotEmpty,
        discountOnly,
      ].where((x) => x).length;

  SpaceQuery copyWith({
    String? text,
    String? categoryId,
    bool clearCategory = false,
    String? studioId,
    List<String>? studioIds,
    Money? minPrice,
    Money? maxPrice,
    bool clearPrice = false,
    DateTime? date,
    int? startMinute,
    bool clearDate = false,
    double? minRating,
    int? minCapacity,
    bool clearCapacity = false,
    Set<String>? facilities,
    Set<String>? equipment,
    bool? discountOnly,
    SpaceSort? sort,
    bool? includeInactive,
  }) =>
      SpaceQuery(
        text: text ?? this.text,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        studioId: studioId ?? this.studioId,
        studioIds: studioIds ?? this.studioIds,
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        date: clearDate ? null : (date ?? this.date),
        startMinute: clearDate ? null : (startMinute ?? this.startMinute),
        minRating: minRating ?? this.minRating,
        minCapacity: clearCapacity ? null : (minCapacity ?? this.minCapacity),
        facilities: facilities ?? this.facilities,
        equipment: equipment ?? this.equipment,
        discountOnly: discountOnly ?? this.discountOnly,
        sort: sort ?? this.sort,
        includeInactive: includeInactive ?? this.includeInactive,
      );

  /// Keeps text, sort and scope; drops every filter.
  SpaceQuery cleared() => SpaceQuery(
        text: text,
        sort: sort,
        studioIds: studioIds,
        includeInactive: includeInactive,
      );
}

abstract class StudioRepository {
  Future<List<Studio>> listStudios({bool includeArchived = false});
  Future<Studio> getStudio(String id);
  Future<Studio> saveStudio(Studio studio, {required AppUser actor});
  Future<void> archiveStudio(String id, {required AppUser actor});
}

abstract class SpaceRepository {
  Future<List<StudioSpace>> listSpaces(SpaceQuery query);
  Future<StudioSpace> getSpace(String id);

  /// Creates (unknown id) or updates a space. Permission-checked by role and
  /// studio scope; throws [Forbidden] otherwise.
  Future<StudioSpace> saveSpace(StudioSpace space, {required AppUser actor});
  Future<StudioSpace> setSpaceStatus(String id, SpaceStatus status,
      {required AppUser actor});
  Future<String> nextSpaceCode(String studioId);

  Future<List<SpaceCategory>> listCategories({bool includeInactive = false});
  Future<SpaceCategory> saveCategory(SpaceCategory category, {required AppUser actor});

  /// Occupied intervals for the calendar: confirmed and pending bookings,
  /// other customers' active holds, and blocks. Pass [exceptUserId] to hide
  /// that customer's own unpaid holds from being shown as busy.
  Future<List<BusyInterval>> busyIntervals(String spaceId);

  Future<List<SpaceAvailability>> listBlocks(String spaceId);
  Future<SpaceAvailability> addBlock(String spaceId,
      {required DateTime start,
      required DateTime end,
      required String reason,
      required AppUser actor});
  Future<void> removeBlock(String blockId, {required AppUser actor});
}
