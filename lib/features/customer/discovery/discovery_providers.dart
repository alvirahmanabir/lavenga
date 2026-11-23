import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/models/promo_social.dart';
import '../../../domain/repositories/booking_repositories.dart';
import '../../../domain/repositories/catalogue_repositories.dart';

/// Studio lookup by id, used to label space cards.
final studioMapProvider = FutureProvider.autoDispose<Map<String, Studio>>((ref) async {
  final studios = await ref.watch(studiosProvider.future);
  return {for (final s in studios) s.id: s};
});

String? _uid(Ref ref) => ref.watch(sessionProvider.select((s) => s.user?.id));

final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  ref.watch(dbVersionProvider);
  final uid = _uid(ref);
  if (uid == null) return Future.value(<String>{});
  return ref.watch(favoriteRepositoryProvider).favoriteIds(uid);
});

final favoriteSpacesProvider = FutureProvider.autoDispose<List<StudioSpace>>((ref) {
  ref.watch(dbVersionProvider);
  final uid = _uid(ref);
  if (uid == null) return Future.value(<StudioSpace>[]);
  return ref.watch(favoriteRepositoryProvider).listFavorites(uid);
});

final recentlyViewedProvider = FutureProvider.autoDispose<List<StudioSpace>>((ref) {
  ref.watch(dbVersionProvider);
  final uid = _uid(ref);
  if (uid == null) return Future.value(<StudioSpace>[]);
  return ref.watch(favoriteRepositoryProvider).recentlyViewed(uid);
});

/// Keys: 'popular', 'recommended', 'newest' or 'studio:<id>'.
final spacesBySectionProvider =
    FutureProvider.autoDispose.family<List<StudioSpace>, String>((ref, key) {
  ref.watch(dbVersionProvider);
  final repo = ref.watch(spaceRepositoryProvider);
  if (key.startsWith('studio:')) {
    return repo.listSpaces(SpaceQuery(studioId: key.substring(7)));
  }
  final sort = switch (key) {
    'popular' => SpaceSort.popularity,
    'newest' => SpaceSort.newest,
    _ => SpaceSort.recommended,
  };
  return repo.listSpaces(SpaceQuery(sort: sort));
});

final offersProvider = FutureProvider.autoDispose<List<OfferView>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(discountRepositoryProvider).activeOffers();
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(dbVersionProvider);
  final uid = _uid(ref);
  if (uid == null) return Future.value(<AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).list(uid);
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(dbVersionProvider);
  final uid = _uid(ref);
  if (uid == null) return Future.value(0);
  return ref.watch(notificationRepositoryProvider).unreadCount(uid);
});

final spaceReviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, spaceId) {
  ref.watch(dbVersionProvider);
  return ref.watch(reviewRepositoryProvider).forSpace(spaceId);
});

/// Distinct facilities and equipment across the catalogue, for filter chips.
class FilterOptions {
  const FilterOptions({this.facilities = const [], this.equipment = const []});
  final List<String> facilities;
  final List<String> equipment;
}

final filterOptionsProvider = FutureProvider.autoDispose<FilterOptions>((ref) async {
  ref.watch(dbVersionProvider);
  final spaces = await ref.watch(spaceRepositoryProvider).listSpaces(const SpaceQuery());
  final facilities = <String>{for (final s in spaces) ...s.facilities}.toList()..sort();
  final equipment = <String>{for (final s in spaces) ...s.equipment}.toList()..sort();
  return FilterOptions(facilities: facilities, equipment: equipment);
});

/// Explore filters live here so they survive opening a space and returning.
class ExploreQueryNotifier extends Notifier<SpaceQuery> {
  @override
  SpaceQuery build() => const SpaceQuery();
  void set(SpaceQuery q) => state = q;
}

final exploreQueryProvider =
    NotifierProvider<ExploreQueryNotifier, SpaceQuery>(ExploreQueryNotifier.new);

final exploreResultsProvider = FutureProvider.autoDispose<List<StudioSpace>>((ref) {
  ref.watch(dbVersionProvider);
  final query = ref.watch(exploreQueryProvider);
  return ref.watch(spaceRepositoryProvider).listSpaces(query);
});
