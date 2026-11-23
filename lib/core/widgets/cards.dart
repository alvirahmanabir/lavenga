import 'package:material_ui/material_ui.dart';

import '../../domain/models/catalogue.dart';
import '../theme/app_tokens.dart';
import 'app_image.dart';
import 'price_and_rating.dart';

IconData categoryIcon(String key) => switch (key) {
      'camera' => Icons.photo_camera_outlined,
      'videocam' => Icons.videocam_outlined,
      'mic' => Icons.mic_none,
      'inventory' => Icons.inventory_2_outlined,
      'fashion' => Icons.checkroom,
      'movie' => Icons.movie_creation_outlined,
      'event' => Icons.celebration_outlined,
      _ => Icons.category_outlined,
    };

/// Keys an administrator can choose from when creating a category.
const categoryIconKeys = [
  'camera', 'videocam', 'mic', 'inventory', 'fashion', 'movie', 'event',
];

/// Space listing card. [width] set = fixed-width carousel card; null = fills
/// its parent (grid or list).
class SpaceCard extends StatelessWidget {
  const SpaceCard({
    super.key,
    required this.space,
    required this.studioName,
    required this.onTap,
    this.location,
    this.isFavorite = false,
    this.onFavorite,
    this.width,
    this.statusLabel,
  });

  final StudioSpace space;
  final String studioName;
  final String? location;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final double? width;

  /// Shown instead of the price row when set (e.g. "Inactive").
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = Semantics(
      button: true,
      label: '${space.name}, $studioName, from ${space.discountedRate.format()} per hour',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppImage(
                  url: space.images.isEmpty ? null : space.images.first,
                  aspectRatio: 4 / 3,
                  semanticLabel: '${space.name} photo',
                ),
                if (space.hasDiscount)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: DiscountBadge(label: '${(space.discountBp / 100).round()}% off'),
                  ),
                if (onFavorite != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        minimumSize: const Size(40, 40),
                      ),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.terracotta : AppColors.ink,
                        size: 20,
                      ),
                      onPressed: onFavorite,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              location == null ? studioName : '$studioName · $location',
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(space.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                RatingStars(rating: space.ratingAvg, count: space.ratingCount),
                if (space.ratingCount > 0) const SizedBox(width: AppSpacing.md),
                const Icon(Icons.people_outline, size: 15, color: AppColors.mutedText),
                const SizedBox(width: 3),
                Text('${space.capacity}', style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            if (statusLabel != null)
              Text(statusLabel!, style: text.labelMedium?.copyWith(color: AppColors.warning))
            else
              PriceText(
                price: space.discountedRate,
                original: space.hasDiscount ? space.hourlyRate : null,
                unit: '/ hour',
              ),
          ],
        ),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.studio,
    required this.onTap,
    this.spaceCount,
    this.width,
  });

  final Studio studio;
  final VoidCallback onTap;
  final int? spaceCount;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = Semantics(
      button: true,
      label: '${studio.name}, ${studio.location}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(url: studio.imageUrl, aspectRatio: 16 / 10, semanticLabel: '${studio.name} photo'),
            const SizedBox(height: AppSpacing.sm),
            Text(studio.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              spaceCount == null ? studio.location : '${studio.location} · $spaceCount spaces',
              style: text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
  });

  final SpaceCategory category;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(categoryIcon(category.icon),
                  color: selected ? AppColors.paper : AppColors.ink),
              const SizedBox(height: 6),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  color: selected ? AppColors.paper : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive column count: 1 phone portrait wide cards use 2, tablets 3-4.
int gridColumnsFor(double width) {
  if (width >= 1100) return 4;
  if (width >= 800) return 3;
  return 2;
}
