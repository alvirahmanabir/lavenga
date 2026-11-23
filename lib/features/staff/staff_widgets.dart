import 'package:material_ui/material_ui.dart';

import '../../core/money/money.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/models/booking.dart';
import '../../domain/repositories/engagement_repositories.dart';

/// Number tile for dashboards. The label always says what the figure is, so
/// booking value, collected, outstanding and refunded are never confused.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.color,
    this.sub,
  });
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: color ?? AppColors.mutedText),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(label,
                        style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: text.headlineSmall?.copyWith(color: color)),
                ),
                if (sub != null) Text(sub!, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of tiles (2 columns on phones, 4 on wide screens).
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * AppSpacing.md) / cols;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      }),
    );
  }
}

/// Simple accessible bar chart: every bar is labelled and has a semantic
/// description, so the data is available without seeing colour or height.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.days});
  final List<DayValue> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('No activity in this period.'),
      );
    }
    final shown = days.length > 14 ? days.sublist(days.length - 14) : days;
    final max = shown.fold<int>(1, (m, d) => d.amount.minor > m ? d.amount.minor : m);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in shown)
            Expanded(
              child: Semantics(
                label: '${fmtDate(d.day)}: ${d.amount.format()}, ${d.count} bookings',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: (d.amount.minor / max).clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.terracotta,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${toStudioLocal(d.day).day}', style: text.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact booking row for staff lists.
class StaffBookingCard extends StatelessWidget {
  const StaffBookingCard({super.key, required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = booking.items.isEmpty ? null : booking.items.first;
    final more = booking.items.length - 1;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(booking.reference, style: text.titleMedium)),
                Text(booking.total.format(), style: text.titleMedium),
              ]),
              const SizedBox(height: 2),
              Text(booking.customerName, style: text.bodyMedium),
              if (first != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${first.spaceName}${more > 0 ? ' +$more more' : ''}',
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${fmtDate(first.schedule.start)} · ${fmtRange(first.schedule)}',
                    style: text.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                BookingStatusBadge(booking.status),
                PaymentStatusBadge(booking.paymentStatus),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells staff why an action is missing instead of silently hiding it.
class NoAccess extends StatelessWidget {
  const NoAccess({super.key, this.what = 'this section'});
  final String what;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.lock_outline,
        title: 'Not available for your role',
        message: 'You do not have permission to open $what. Ask an administrator if you need access.',
      );
}

String moneyText(Money m) => m.format();
