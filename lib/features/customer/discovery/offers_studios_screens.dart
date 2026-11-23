import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/data_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_widgets.dart';
import 'discovery_providers.dart';
import 'discovery_widgets.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Special offers')),
      body: AsyncBody(
        value: offers,
        onRetry: () => ref.invalidate(offersProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No offers right now',
              message: 'New offers appear here. Check back soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => OfferCard(offer: items[i]),
          );
        },
      ),
    );
  }
}

class StudioListScreen extends ConsumerWidget {
  const StudioListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studios = ref.watch(studiosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Studios')),
      body: AsyncBody(
        value: studios,
        onRetry: () => ref.invalidate(studiosProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.store_outlined,
              title: 'No studios yet',
              message: 'Studios will appear here once they are listed.',
            );
          }
          return LayoutBuilder(builder: (context, c) {
            final cols = gridColumnsFor(c.maxWidth) - 1;
            const gap = AppSpacing.lg;
            final w = (c.maxWidth - AppSpacing.gutter * 2 - gap * (cols - 1)) / cols;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Wrap(
                spacing: gap,
                runSpacing: AppSpacing.xl,
                children: [
                  for (final s in items)
                    StudioCard(
                      studio: s,
                      width: w,
                      onTap: () => context.push('/c/studio/${s.id}'),
                    ),
                ],
              ),
            );
          });
        },
      ),
    );
  }
}

class StudioDetailScreen extends ConsumerWidget {
  const StudioDetailScreen({super.key, required this.studioId});
  final String studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studio = ref.watch(studioProvider(studioId));
    final spaces = ref.watch(spacesBySectionProvider('studio:$studioId'));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(studio.value?.name ?? 'Studio')),
      body: AsyncBody(
        value: studio,
        onRetry: () => ref.invalidate(studioProvider(studioId)),
        data: (s) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: AppImage(url: s.imageUrl, aspectRatio: 16 / 9, semanticLabel: '${s.name} photo'),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: text.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  InfoRow(Icons.place_outlined, '${s.address}, ${s.location}'),
                  const SizedBox(height: AppSpacing.md),
                  Text(s.description, style: text.bodyLarge),
                ],
              ),
            ),
            const SectionHeader('Spaces'),
            if (spaces.hasValue && spaces.requireValue.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: Text('This studio has no bookable spaces right now.'),
              )
            else if (spaces.hasValue)
              SpaceGrid(spaces: spaces.requireValue)
            else
              const SizedBox(height: 240, child: ListSkeleton(count: 1)),
          ],
        ),
      ),
    );
  }
}
