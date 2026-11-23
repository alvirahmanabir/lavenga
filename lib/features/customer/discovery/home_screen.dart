import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/data_providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/models/promo_social.dart';
import 'discovery_providers.dart';
import 'discovery_widgets.dart';

/// Horizontal rail of space cards with working hearts.
class SpaceRail extends ConsumerWidget {
  const SpaceRail({super.key, required this.spaces});
  final List<StudioSpace> spaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studios = ref.watch(studioMapProvider).value ?? const <String, Studio>{};
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    return HScroll(
      children: [
        for (final s in spaces)
          SpaceCard(
            space: s,
            width: 240,
            studioName: studios[s.studioId]?.name ?? '',
            location: studios[s.studioId]?.area,
            isFavorite: favorites.contains(s.id),
            onFavorite: () => toggleFavorite(context, ref, s.id),
            onTap: () => context.push('/c/space/${s.id}'),
          ),
      ],
    );
  }
}

class _SectionRail extends ConsumerWidget {
  const _SectionRail({required this.title, required this.sectionKey, this.max = 8});
  final String title;
  final String sectionKey;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(spacesBySectionProvider(sectionKey));
    final spaces = value.value;
    if (spaces == null || spaces.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, actionLabel: 'See all', onAction: () => context.push('/c/search')),
        SpaceRail(spaces: spaces.take(max).toList()),
      ],
    );
  }
}

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider).value;
    final offers = ref.watch(offersProvider).value ?? const [];
    final recent = ref.watch(recentlyViewedProvider).value ?? const <StudioSpace>[];
    final studios = ref.watch(studiosProvider).value ?? const <Studio>[];
    final text = Theme.of(context).textTheme;
    final banners = [...?settings?.banners.where((b) => b.active)];
    final firstName = (user?.fullName ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lavenga', style: text.titleLarge),
        actions: [
          IconButton(
            tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () => context.push('/c/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(spacesBySectionProvider);
          ref.invalidate(studiosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(firstName.isEmpty ? 'Hello' : 'Hello, $firstName',
                      style: text.headlineMedium),
                  const SizedBox(height: 2),
                  Text('Where will you create next?', style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  SearchField(
                    readOnly: true,
                    onChanged: (_) {},
                    onTap: () => context.push('/c/search'),
                  ),
                ],
              ),
            ),
            if (banners.isNotEmpty) _BannerCarousel(banners: banners),
            const SectionHeader('Browse by category'),
            categories.when(
              data: (cats) => HScroll(
                spacing: AppSpacing.sm,
                children: [
                  for (final c in cats)
                    CategoryCard(
                      category: c,
                      onTap: () => context.push('/c/category/${c.id}'),
                    ),
                ],
              ),
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox.shrink(),
            ),
            if (offers.isNotEmpty) ...[
              SectionHeader('Special offers',
                  actionLabel: 'See all', onAction: () => context.push('/c/offers')),
              HScroll(children: [
                for (final o in offers.take(5)) OfferCard(offer: o, width: 260),
              ]),
            ],
            if (recent.isNotEmpty) ...[
              const SectionHeader('Recently viewed'),
              SpaceRail(spaces: recent.take(8).toList()),
            ],
            const _SectionRail(title: 'Popular spaces', sectionKey: 'popular'),
            const _SectionRail(title: 'Recommended for you', sectionKey: 'recommended'),
            const _SectionRail(title: 'New on Lavenga', sectionKey: 'newest'),
            if (studios.isNotEmpty) ...[
              SectionHeader('Studios',
                  actionLabel: 'See all', onAction: () => context.push('/c/studios')),
              HScroll(children: [
                for (final s in studios)
                  StudioCard(
                    studio: s,
                    width: 240,
                    onTap: () => context.push('/c/studio/${s.id}'),
                  ),
              ]),
            ],
            if (!ref.watch(spacesBySectionProvider('popular')).hasValue)
              const SizedBox(height: 320, child: ListSkeleton(count: 2)),
          ],
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});
  final List<HomeBanner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.banners.length,
        itemBuilder: (context, i) {
          final b = widget.banners[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Semantics(
              label: '${b.title}. ${b.subtitle}',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: b.imageUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(b.title,
                            style: text.titleLarge?.copyWith(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(b.subtitle,
                            style: text.bodySmall?.copyWith(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
