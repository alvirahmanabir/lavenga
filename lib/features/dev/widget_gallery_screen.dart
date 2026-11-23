import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/price_and_rating.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';

/// Living style guide for the design system. Reachable from the login screen.
class WidgetGalleryScreen extends StatelessWidget {
  const WidgetGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          section(
            'Buttons',
            Column(children: [
              AppButton(label: 'Primary', onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                  label: 'Secondary',
                  kind: AppButtonKind.secondary,
                  onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Loading', loading: true, onPressed: () {}),
              const SizedBox(height: AppSpacing.sm),
              const AppButton(label: 'Disabled', onPressed: null),
            ]),
          ),
          section(
            'Status badges',
            const Wrap(spacing: 8, runSpacing: 8, children: [
              StatusBadge(
                  label: 'Confirmed',
                  icon: Icons.check_circle,
                  tone: StatusTone.success),
              StatusBadge(
                  label: 'Pending review',
                  icon: Icons.schedule,
                  tone: StatusTone.warning),
              StatusBadge(
                  label: 'Payment failed',
                  icon: Icons.error,
                  tone: StatusTone.error),
              StatusBadge(
                  label: 'Balance due',
                  icon: Icons.payments_outlined,
                  tone: StatusTone.info),
              StatusBadge(
                  label: 'Draft', icon: Icons.edit, tone: StatusTone.neutral),
            ]),
          ),
          section(
            'Price and rating',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriceText(
                  price: Money.taka(2200),
                  original: Money.taka(2750),
                  unit: '/ hour',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Row(children: [
                  DiscountBadge(label: '20% off'),
                  SizedBox(width: AppSpacing.md),
                  RatingStars(rating: 4.8, count: 36),
                ]),
              ],
            ),
          ),
          section(
            'Loading skeleton',
            const Column(children: [
              SkeletonBox(height: 140, radius: AppRadii.card),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 180),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120),
            ]),
          ),
          section(
            'Empty state',
            const SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.favorite_border,
                title: 'No favourites yet',
                message: 'Tap the heart on any space to save it here.',
              ),
            ),
          ),
          section(
            'Error state',
            SizedBox(
              height: 240,
              child: ErrorState(
                failure: const NetworkFailure(),
                onRetry: () {},
              ),
            ),
          ),
          section(
            'Confirmation dialog',
            Builder(
              builder: (context) => AppButton(
                label: 'Cancel booking…',
                kind: AppButtonKind.secondary,
                onPressed: () => showConfirmDialog(
                  context,
                  title: 'Cancel this booking?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Cancel booking',
                  cancelLabel: 'Keep booking',
                  destructive: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
