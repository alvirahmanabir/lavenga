import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../core/utils/time_format.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/catalogue_repositories.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../../domain/services/availability_service.dart';
import '../../domain/services/policies.dart';
import 'mock_context.dart';

class MockStudioRepository extends MockRepo implements StudioRepository {
  MockStudioRepository(super.ctx);

  @override
  Future<List<Studio>> listStudios({bool includeArchived = false}) async =>
      db.studios.where((s) => includeArchived || !s.archived).toList();

  @override
  Future<Studio> getStudio(String id) async {
    for (final s in db.studios) {
      if (s.id == id) return s;
    }
    throw const NotFoundFailure('studio');
  }

  @override
  Future<Studio> saveStudio(Studio studio, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (studio.name.trim().isEmpty) throw const ValidationFailure('Studio name is required');
    final i = db.studios.indexWhere((s) => s.id == studio.id);
    late Studio saved;
    if (i < 0) {
      saved = Studio(
        id: db.newId('st'),
        name: studio.name,
        description: studio.description,
        address: studio.address,
        area: studio.area,
        city: studio.city,
        imageUrl: studio.imageUrl,
        createdAt: now,
      );
      db.studios.add(saved);
    } else {
      saved = studio;
      db.studios[i] = studio;
    }
    audit(actor, i < 0 ? 'Created studio' : 'Updated studio', saved.name);
    commit();
    return saved;
  }

  @override
  Future<void> archiveStudio(String id, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    final i = db.studios.indexWhere((s) => s.id == id);
    if (i < 0) throw const NotFoundFailure('studio');
    // History is preserved: bookings keep their snapshots; spaces are archived too.
    db.studios[i] = db.studios[i].copyWith(archived: true);
    for (var k = 0; k < db.spaces.length; k++) {
      if (db.spaces[k].studioId == id) {
        db.spaces[k] = db.spaces[k].copyWith(status: SpaceStatus.archived);
      }
    }
    audit(actor, 'Archived studio', db.studios[i].name, sensitive: true);
    commit();
  }
}

class MockSpaceRepository extends MockRepo implements SpaceRepository {
  MockSpaceRepository(super.ctx);

  String _categoryName(String id) {
    for (final c in db.categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  Studio? _studio(String id) {
    for (final s in db.studios) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<List<StudioSpace>> listSpaces(SpaceQuery q) async {
    sweepHolds();
    final tokens = q.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    bool matches(StudioSpace s) {
      final studio = _studio(s.studioId);
      if (s.status == SpaceStatus.archived) return false;
      if (!q.includeInactive) {
        if (s.status != SpaceStatus.active) return false;
        if (studio == null || studio.archived) return false;
      }
      if (q.studioIds != null && !q.studioIds!.contains(s.studioId)) return false;
      if (q.studioId != null && s.studioId != q.studioId) return false;
      if (q.categoryId != null && s.categoryId != q.categoryId) return false;
      if (tokens.isNotEmpty) {
        final hay = [
          s.name,
          s.code,
          studio?.name ?? '',
          studio?.location ?? '',
          studio?.address ?? '',
          _categoryName(s.categoryId),
          s.description,
          ...s.facilities,
          ...s.equipment,
        ].join(' ').toLowerCase();
        if (!tokens.every(hay.contains)) return false;
      }
      final rate = s.discountedRate;
      if (q.minPrice != null && rate < q.minPrice!) return false;
      if (q.maxPrice != null && rate > q.maxPrice!) return false;
      if (q.minRating > 0 && (s.ratingCount == 0 || s.ratingAvg < q.minRating)) return false;
      if (q.minCapacity != null && s.capacity < q.minCapacity!) return false;
      if (q.facilities.isNotEmpty && !q.facilities.every(s.facilities.contains)) return false;
      if (q.equipment.isNotEmpty && !q.equipment.every(s.equipment.contains)) return false;
      if (q.discountOnly && !s.hasDiscount) return false;
      if (q.date != null) {
        final slots = AvailabilityService.startSlots(
          space: s,
          dayStart: q.date!,
          busy: busyFor(s.id),
          now: now,
        );
        if (q.startMinute != null) {
          final start = q.date!.add(Duration(minutes: q.startMinute!));
          final hit = slots.where((x) => x.start == start);
          if (hit.isEmpty || hit.first.state != SlotState.available) return false;
        } else if (!slots.any((x) => x.state == SlotState.available)) {
          return false;
        }
      }
      return true;
    }

    final list = db.spaces.where(matches).toList();
    final featured = db.settings.featuredSpaceIds;
    switch (q.sort) {
      case SpaceSort.recommended:
        double score(StudioSpace s) =>
            s.popularity + s.ratingAvg * 8 + (featured.contains(s.id) ? 25 : 0);
        list.sort((a, b) => score(b).compareTo(score(a)));
      case SpaceSort.priceLow:
        list.sort((a, b) => a.discountedRate.compareTo(b.discountedRate));
      case SpaceSort.priceHigh:
        list.sort((a, b) => b.discountedRate.compareTo(a.discountedRate));
      case SpaceSort.rating:
        list.sort((a, b) {
          final byAvg = b.ratingAvg.compareTo(a.ratingAvg);
          return byAvg != 0 ? byAvg : b.ratingCount.compareTo(a.ratingCount);
        });
      case SpaceSort.popularity:
        list.sort((a, b) => b.popularity.compareTo(a.popularity));
      case SpaceSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Future<StudioSpace> getSpace(String id) async => spaceById(id);

  @override
  Future<StudioSpace> saveSpace(StudioSpace space, {required AppUser actor}) async {
    await wait();
    final user = fresh(actor);
    final i = db.spaces.indexWhere((s) => s.id == space.id);
    final isNew = i < 0;
    if (user.isCustomer) throw const Forbidden('spaces');
    if (!PermissionPolicy.managesStudio(user, space.studioId)) {
      throw const Forbidden('outside your studios');
    }
    if (!user.isAdmin) {
      requirePermission(user, isNew ? StaffPermission.createSpaces : StaffPermission.manageSpaces);
      if (!isNew) {
        final old = db.spaces[i];
        final priceChanged =
            old.hourlyRate != space.hourlyRate || old.discountBp != space.discountBp;
        if (priceChanged) requirePermission(user, StaffPermission.managePricing);
      } else {
        requirePermission(user, StaffPermission.managePricing);
      }
    }
    if (space.name.trim().isEmpty) throw const ValidationFailure('Space name is required');
    if (space.code.trim().isEmpty) throw const ValidationFailure('Space code is required');
    if (!space.hourlyRate.isPositive) throw const ValidationFailure('Hourly rate must be above zero');
    if (space.minMinutes <= 0 || space.maxMinutes < space.minMinutes) {
      throw const ValidationFailure('Maximum duration must be at least the minimum');
    }
    if (space.hours.closeMinute <= space.hours.openMinute) {
      throw const ValidationFailure('Closing time must be after opening time');
    }
    final duplicate = db.spaces.any(
      (s) => s.id != space.id && s.code.toLowerCase() == space.code.trim().toLowerCase(),
    );
    if (duplicate) throw const ValidationFailure('That space code is already in use', field: 'code');

    final saved = isNew
        ? StudioSpace(
            id: db.newId('sp'),
            code: space.code.trim(),
            studioId: space.studioId,
            name: space.name.trim(),
            categoryId: space.categoryId,
            description: space.description,
            images: space.images,
            facilities: space.facilities,
            equipment: space.equipment,
            rules: space.rules,
            capacity: space.capacity,
            dimensions: space.dimensions,
            hourlyRate: space.hourlyRate,
            discountBp: space.discountBp,
            hours: space.hours,
            minMinutes: space.minMinutes,
            maxMinutes: space.maxMinutes,
            bufferMinutes: space.bufferMinutes,
            status: space.status,
            createdAt: now,
          )
        : space.copyWith(code: space.code.trim(), name: space.name.trim());
    if (isNew) {
      db.spaces.add(saved);
    } else {
      db.spaces[i] = saved;
    }
    audit(user, isNew ? 'Created space' : 'Updated space', '${saved.code} ${saved.name}');
    commit();
    return saved;
  }

  @override
  Future<StudioSpace> setSpaceStatus(String id, SpaceStatus status,
      {required AppUser actor}) async {
    await wait();
    final user = fresh(actor);
    final space = spaceById(id);
    if (status == SpaceStatus.archived) {
      requireAdmin(user);
    } else {
      requirePermission(user, StaffPermission.manageSpaces, studioId: space.studioId);
    }
    final updated = space.copyWith(status: status);
    db.spaces[db.spaces.indexWhere((s) => s.id == id)] = updated;
    audit(user, 'Set space ${status.name}', '${space.code} ${space.name}',
        sensitive: status == SpaceStatus.archived);
    commit();
    return updated;
  }

  @override
  Future<String> nextSpaceCode(String studioId) async {
    final studio = _studio(studioId);
    final initials = (studio?.name ?? 'SP')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    var n = db.spaces.where((s) => s.studioId == studioId).length + 1;
    String code() => '$initials-NEW-${n.toString().padLeft(2, '0')}';
    while (db.spaces.any((s) => s.code == code())) {
      n++;
    }
    return code();
  }

  @override
  Future<List<SpaceCategory>> listCategories({bool includeInactive = false}) async =>
      db.categories.where((c) => includeInactive || c.active).toList();

  @override
  Future<SpaceCategory> saveCategory(SpaceCategory category, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (category.name.trim().isEmpty) throw const ValidationFailure('Category name is required');
    final i = db.categories.indexWhere((c) => c.id == category.id);
    final saved = i < 0
        ? SpaceCategory(
            id: db.newId('cat'),
            name: category.name.trim(),
            icon: category.icon,
            active: category.active,
          )
        : category;
    if (i < 0) {
      db.categories.add(saved);
    } else {
      db.categories[i] = saved;
    }
    audit(actor, i < 0 ? 'Created category' : 'Updated category', saved.name);
    commit();
    return saved;
  }

  @override
  Future<List<BusyInterval>> busyIntervals(String spaceId) async {
    sweepHolds();
    return busyFor(spaceId);
  }

  @override
  Future<List<SpaceAvailability>> listBlocks(String spaceId) async =>
      db.blocks.where((b) => b.spaceId == spaceId).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  @override
  Future<SpaceAvailability> addBlock(
    String spaceId, {
    required DateTime start,
    required DateTime end,
    required String reason,
    required AppUser actor,
  }) async {
    await wait();
    final space = spaceById(spaceId);
    requirePermission(actor, StaffPermission.manageSpaces, studioId: space.studioId);
    if (!end.isAfter(start)) throw const ValidationFailure('End must be after start');
    if (reason.trim().isEmpty) throw const ValidationFailure('Add a reason for the block');
    sweepHolds();
    final schedule = BookingSchedule(start: start, end: end);
    for (final b in busyFor(spaceId)) {
      if (b.kind != SlotState.unavailable && schedule.overlaps(b.schedule)) {
        throw SlotConflict(
          'That period overlaps an existing booking (${fmtRange(b.schedule)}). '
          'Resolve the booking first.',
        );
      }
    }
    final block = SpaceAvailability(
      id: db.newId('blk'),
      spaceId: spaceId,
      start: start,
      end: end,
      reason: reason.trim(),
    );
    db.blocks.add(block);
    audit(actor, 'Blocked space calendar', '${space.code} ${space.name}', detail: reason);
    commit();
    return block;
  }

  @override
  Future<void> removeBlock(String blockId, {required AppUser actor}) async {
    await wait();
    final i = db.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) throw const NotFoundFailure('block');
    final space = spaceById(db.blocks[i].spaceId);
    requirePermission(actor, StaffPermission.manageSpaces, studioId: space.studioId);
    db.blocks.removeAt(i);
    commit();
  }
}

class MockFavoriteRepository extends MockRepo implements FavoriteRepository {
  MockFavoriteRepository(super.ctx);

  @override
  Future<Set<String>> favoriteIds(String userId) async =>
      {for (final f in db.favorites.where((f) => f.userId == userId)) f.spaceId};

  @override
  Future<bool> toggle(String userId, String spaceId) async {
    final i = db.favorites.indexWhere((f) => f.userId == userId && f.spaceId == spaceId);
    final nowFavorite = i < 0;
    if (nowFavorite) {
      db.favorites.add(CustomerFavorite(userId: userId, spaceId: spaceId, at: now));
    } else {
      db.favorites.removeAt(i);
    }
    commit();
    return nowFavorite;
  }

  List<StudioSpace> _resolve(Iterable<String> ids) {
    final out = <StudioSpace>[];
    for (final id in ids) {
      for (final s in db.spaces) {
        if (s.id == id && s.status != SpaceStatus.archived) out.add(s);
      }
    }
    return out;
  }

  @override
  Future<List<StudioSpace>> listFavorites(String userId) async {
    final ids = db.favorites.where((f) => f.userId == userId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return _resolve(ids.map((f) => f.spaceId));
  }

  @override
  Future<List<StudioSpace>> recentlyViewed(String userId) async =>
      _resolve(db.viewed[userId] ?? const []);

  @override
  Future<void> markViewed(String userId, String spaceId) async {
    final list = [...(db.viewed[userId] ?? const <String>[])]
      ..remove(spaceId)
      ..insert(0, spaceId);
    db.viewed[userId] = list.take(10).toList();
    db.persist();
  }
}
