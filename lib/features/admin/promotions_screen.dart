import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/clock/clock.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/promo_social.dart';
import 'admin_common.dart';

/// Discounts and coupon codes. Offers apply only through the pricing
/// service; the booking keeps a snapshot, so editing never changes old orders.
class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounts = ref.watch(discountsProvider);
    final coupons = ref.watch(couponsProvider);
    final now = ref.watch(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/a/discount/new'),
        icon: const Icon(Icons.add),
        label: const Text('New discount'),
      ),
      body: AdminBody(
        child: AsyncBody<List<Discount>>(
          value: discounts,
          onRetry: () => ref.invalidate(discountsProvider),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No discounts yet',
                message: 'Create a discount, then optionally attach a coupon code.',
                actionLabel: 'New discount',
                onAction: () => context.push('/a/discount/new'),
              );
            }
            final codes = coupons.valueOrNull ?? const <Coupon>[];
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final d = list[i];
                final mine = codes.where((c) => c.discountId == d.id).toList();
                final expired = d.endsAt.isBefore(now);
                final state = !d.active
                    ? 'Paused'
                    : expired
                        ? 'Expired'
                        : d.startsAt.isAfter(now)
                            ? 'Scheduled'
                            : 'Live';
                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    onTap: () => context.push('/a/discount/${d.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(d.name, style: Theme.of(context).textTheme.titleMedium),
                              ),
                              Chip(label: Text(state)),
                            ],
                          ),
                          Text('${d.valueLabel} · ${_scopeLabel(d.scope)}',
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppSpacing.xs),
                          InfoRow(Icons.event_outlined,
                              '${fmtDate(d.startsAt)} to ${fmtDate(d.endsAt)}'),
                          if (mine.isNotEmpty)
                            InfoRow(Icons.confirmation_number_outlined,
                                mine.map((c) => '${c.code} (${c.usedCount} used)').join(', ')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _scopeLabel(DiscountScope s) => switch (s) {
      DiscountScope.global => 'All spaces',
      DiscountScope.space => 'Selected spaces',
      DiscountScope.category => 'Selected categories',
      DiscountScope.customer => 'Selected customers',
    };

/// Shared label helper for the form screen.
String discountScopeLabel(DiscountScope s) => _scopeLabel(s);
