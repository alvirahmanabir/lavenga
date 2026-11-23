import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/repositories/booking_repositories.dart';
import 'discovery_providers.dart';

/// Toggles a favourite and shows feedback. Errors are never silent.
Future<void> toggleFavorite(BuildContext context, WidgetRef ref, String spaceId) async {
  final uid = ref.read(sessionProvider).user?.id;
  if (uid == null) return;
  var added = false;
  final ok = await runGuarded(context, () async {
    added = await ref.read(favoriteRepositoryProvider).toggle(uid, spaceId);
  });
  if (ok && context.mounted) {
    showAppSnack(context, added ? 'Saved to favourites' : 'Removed from favourites');
  }
}

/// Selectable chip with readable contrast in both states.
class OptionChip extends StatelessWidget {
  const OptionChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.paper : AppColors.ink,
            ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.ink,
      onSelected: (_) => onTap(),
    );
  }
}

/// Horizontal scroller that sizes to its content (no fixed height).
class HScroll extends StatelessWidget {
  const HScroll({super.key, required this.children, this.spacing = AppSpacing.md});
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Responsive grid of space cards with working favourite hearts.
class SpaceGrid extends ConsumerWidget {
  const SpaceGrid({super.key, required this.spaces});
  final List<StudioSpace> spaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studios = ref.watch(studioMapProvider).value ?? const <String, Studio>{};
    final favorites = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.lg;
        final cols = gridColumnsFor(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - AppSpacing.gutter * 2 - spacing * (cols - 1)) / cols;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Wrap(
            spacing: spacing,
            runSpacing: AppSpacing.xl,
            children: [
              for (final s in spaces)
                SpaceCard(
                  space: s,
                  width: cardWidth,
                  studioName: studios[s.studioId]?.name ?? '',
                  location: studios[s.studioId]?.area,
                  isFavorite: favorites.contains(s.id),
                  onFavorite: () => toggleFavorite(context, ref, s.id),
                  onTap: () => context.push('/c/space/${s.id}'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Offer card with a copyable coupon code.
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, this.width});
  final OfferView offer;
  final double? width;

  String get _scope => switch (offer.discount.scope) {
        DiscountScope.global => 'Any space',
        DiscountScope.space => 'Selected space',
        DiscountScope.category => 'Selected category',
        DiscountScope.customer => 'Members',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = offer.discount;
    final coupon = offer.coupon;
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.terracotta),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(d.name, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(d.valueLabel, style: text.headlineSmall?.copyWith(color: AppColors.terracotta)),
            const SizedBox(height: AppSpacing.sm),
            Text(_scope, style: text.bodySmall),
            if (d.minBooking.isPositive)
              Text('Minimum booking ${d.minBooking.format()}', style: text.bodySmall),
            if (d.maxDiscount != null)
              Text('Discount up to ${d.maxDiscount!.format()}', style: text.bodySmall),
            Text('Valid until ${fmtDateLong(d.endsAt)}', style: text.bodySmall),
            if (coupon != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(AppBreakpoints.minTouchTarget, AppBreakpoints.minTouchTarget),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(coupon.code),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: coupon.code));
                  if (context.mounted) {
                    showAppSnack(context, 'Code ${coupon.code} copied. Apply it at checkout.');
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}
