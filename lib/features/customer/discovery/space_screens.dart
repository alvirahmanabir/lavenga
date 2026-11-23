import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/price_and_rating.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/models/promo_social.dart';
import 'discovery_providers.dart';
import 'discovery_widgets.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final uid = ref.read(sessionProvider).user?.id;
      if (!mounted || uid == null) return;
      ref.read(favoriteRepositoryProvider).markViewed(uid, widget.spaceId).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Widget _chips(List<String> items) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final f in items)
            Chip(
              label: Text(f, style: Theme.of(context).textTheme.labelLarge),
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.line),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final spaceValue = ref.watch(spaceProvider(widget.spaceId));
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    final reviews = ref.watch(spaceReviewsProvider(widget.spaceId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (spaceValue.hasValue)
            IconButton(
              tooltip: favorites.contains(widget.spaceId)
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              icon: Icon(
                favorites.contains(widget.spaceId) ? Icons.favorite : Icons.favorite_border,
                color: favorites.contains(widget.spaceId) ? AppColors.terracotta : null,
              ),
              onPressed: () => toggleFavorite(context, ref, widget.spaceId),
            ),
        ],
      ),
      body: AsyncBody(
        value: spaceValue,
        onRetry: () => ref.invalidate(spaceProvider(widget.spaceId)),
        data: (s) {
          final studio = ref.watch(studioProvider(s.studioId)).value;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  children: [
                    _Gallery(space: s, controller: _page, onChanged: (i) => setState(() => _index = i), index: _index),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (studio != null)
                            InkWell(
                              onTap: () => context.push('/c/studio/${studio.id}'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                child: Text('${studio.name} · ${studio.location}',
                                    style: text.bodyMedium?.copyWith(
                                        decoration: TextDecoration.underline)),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(s.name, style: text.headlineMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Row(children: [
                            RatingStars(rating: s.ratingAvg, count: s.ratingCount),
                            if (s.ratingCount == 0) Text('No reviews yet', style: text.bodySmall),
                            const Spacer(),
                            Text(s.code, style: text.bodySmall),
                          ]),
                          const SizedBox(height: AppSpacing.md),
                          Row(children: [
                            PriceText(
                              price: s.discountedRate,
                              original: s.hasDiscount ? s.hourlyRate : null,
                              unit: '/ hour',
                            ),
                            if (s.hasDiscount) ...[
                              const SizedBox(width: AppSpacing.md),
                              DiscountBadge(label: '${(s.discountBp / 100).round()}% off'),
                            ],
                          ]),
                          if (!s.isBookable) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadii.field),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline, color: AppColors.warning),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text('This space is not accepting bookings right now.')),
                              ]),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Text(s.description, style: text.bodyLarge),
                          const SizedBox(height: AppSpacing.lg),
                          InfoRow(Icons.people_outline, 'Up to ${s.capacity} people'),
                          const SizedBox(height: AppSpacing.sm),
                          InfoRow(Icons.straighten, s.dimensions),
                          const SizedBox(height: AppSpacing.sm),
                          InfoRow(Icons.schedule, 'Open ${s.hours.label}'),
                          const SizedBox(height: AppSpacing.sm),
                          InfoRow(Icons.timelapse,
                              'Book ${fmtDuration(s.minMinutes)} to ${fmtDuration(s.maxMinutes)} per slot'),
                          if (s.facilities.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text('Facilities', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            _chips(s.facilities),
                          ],
                          if (s.equipment.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text('Equipment', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            _chips(s.equipment),
                          ],
                          if (s.rules.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text('Rules', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            for (final r in s.rules)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(Icons.check, size: 16, color: AppColors.mutedText),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(r)),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    SectionHeader(
                      'Reviews',
                      actionLabel: s.ratingCount > 0 ? 'See all' : null,
                      onAction: () => context.push('/c/space/${s.id}/reviews'),
                    ),
                    reviews.when(
                      data: (list) => list.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                              child: Text('Be the first to review after your session.'),
                            )
                          : Column(children: [
                              for (final r in list.take(2)) ReviewTile(review: r),
                            ]),
                      loading: () => const SizedBox(height: 60),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: AppButton(
                    label: s.isBookable ? 'Check availability' : 'Unavailable',
                    icon: Icons.event_available_outlined,
                    onPressed: s.isBookable ? () => context.push('/c/schedule/${s.id}') : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.space,
    required this.controller,
    required this.onChanged,
    required this.index,
  });
  final StudioSpace space;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final int index;

  @override
  Widget build(BuildContext context) {
    final images = space.images;
    if (images.isEmpty) {
      return const AspectRatio(aspectRatio: 4 / 3, child: AppImage(url: null, radius: 0));
    }
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: onChanged,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => context.push('/c/gallery/${space.id}?i=$i'),
              child: AppImage(
                url: images[i],
                radius: 0,
                semanticLabel: '${space.name} photo ${i + 1} of ${images.length}. Tap to enlarge',
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: i == index ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key, required this.spaceId, this.initialIndex = 0});
  final String spaceId;
  final int initialIndex;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final space = ref.watch(spaceProvider(widget.spaceId));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(space.hasValue ? '${_index + 1} / ${space.requireValue.images.length}' : ''),
      ),
      body: AsyncBody(
        value: space,
        loading: const Center(child: CircularProgressIndicator()),
        data: (s) => s.images.isEmpty
            ? const Center(child: Text('No photos', style: TextStyle(color: Colors.white)))
            : PageView.builder(
                controller: _controller,
                itemCount: s.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: AppImage(
                      url: s.images[i],
                      radius: 0,
                      fit: BoxFit.contain,
                      semanticLabel: '${s.name} photo ${i + 1}',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class ReviewTile extends ConsumerWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(name: review.customerName, radius: 16),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(review.customerName, style: text.titleSmall)),
            Text(fmtAgo(review.createdAt, now), style: text.bodySmall),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Rated ${review.rating} out of 5',
            excludeSemantics: true,
            child: Row(children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= review.rating ? Icons.star : Icons.star_border,
                    size: 16, color: AppColors.terracotta),
            ]),
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(review.comment, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class SpaceReviewsScreen extends ConsumerWidget {
  const SpaceReviewsScreen({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(spaceReviewsProvider(spaceId));
    final space = ref.watch(spaceProvider(spaceId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(space == null ? 'Reviews' : 'Reviews · ${space.name}')),
      body: AsyncBody(
        value: reviews,
        onRetry: () => ref.invalidate(spaceReviewsProvider(spaceId)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'No reviews yet',
              message: 'Reviews from customers who completed a session appear here.',
            );
          }
          return ListView.separated(
            itemCount: list.length + (space == null ? 0 : 1),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (space != null && i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Row(children: [
                    Text(space.ratingAvg.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(width: AppSpacing.md),
                    Text('${space.ratingCount} reviews'),
                  ]),
                );
              }
              return ReviewTile(review: list[i - (space == null ? 0 : 1)]);
            },
          );
        },
      ),
    );
  }
}
