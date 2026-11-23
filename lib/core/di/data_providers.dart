import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/promo_social.dart';
import 'providers.dart';

/// Small read-only providers shared by many screens. Each watches
/// [dbVersionProvider] so it refreshes after any mutation.

final categoriesProvider = FutureProvider.autoDispose<List<SpaceCategory>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).listCategories();
});

final allCategoriesProvider = FutureProvider.autoDispose<List<SpaceCategory>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).listCategories(includeInactive: true);
});

final studiosProvider = FutureProvider.autoDispose<List<Studio>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(studioRepositoryProvider).listStudios();
});

final settingsProvider = FutureProvider.autoDispose<PlatformSettings>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(adminRepositoryProvider).getSettings();
});

final spaceProvider = FutureProvider.autoDispose.family<StudioSpace, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(spaceRepositoryProvider).getSpace(id);
});

final studioProvider = FutureProvider.autoDispose.family<Studio, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(studioRepositoryProvider).getStudio(id);
});

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(bookingRepositoryProvider).getBooking(id);
});
