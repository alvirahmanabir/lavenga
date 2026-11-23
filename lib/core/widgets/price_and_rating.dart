import 'package:material_ui/material_ui.dart';

import '../money/money.dart';
import '../theme/app_tokens.dart';

/// Price with optional struck-through original and a discount badge.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.original,
    this.unit,
  });

  final Money price;
  final Money? original;
  final String? unit; // e.g. "/ hour"

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasDiscount = original != null && original! > price;
    return Semantics(
      label: hasDiscount
          ? '${price.format()} ${unit ?? ''}, was ${original!.format()}'
          : '${price.format()} ${unit ?? ''}',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.sm,
        children: [
          Text(
            price.format(),
            style: text.titleLarge?.copyWith(color: AppColors.terracotta),
          ),
          if (hasDiscount)
            Text(
              original!.format(),
              style: text.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          if (unit != null) Text(unit!, style: text.bodySmall),
        ],
      ),
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// Rating display. Per the SRS, show only when verified reviews exist:
/// pass `count: 0` to render nothing.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: 'Rated ${rating.toStringAsFixed(1)} out of 5, $count reviews',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: AppColors.terracotta),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
