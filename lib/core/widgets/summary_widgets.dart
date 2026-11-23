import 'package:material_ui/material_ui.dart';

import '../../domain/models/booking.dart';
import '../money/money.dart';
import '../theme/app_tokens.dart';
import '../utils/time_format.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Label on the left, value on the right. Used throughout summaries.
class SummaryRow extends StatelessWidget {
  const SummaryRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
    this.valueColor,
    this.sub,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = bold ? text.titleMedium : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (sub != null) Text(sub!, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedText),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Card wrapper with standard padding.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.margin});
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Itemised pricing: lines, discounts, fees, total, advance.
class PricingSummary extends StatelessWidget {
  const PricingSummary(this.pricing, {super.key, this.showAdvance = true});
  final BookingPricingSnapshot pricing;
  final bool showAdvance;

  @override
  Widget build(BuildContext context) {
    final p = pricing;
    return Column(
      children: [
        for (final l in p.lines)
          SummaryRow(l.label, l.gross.format(), sub: fmtDuration(l.minutes)),
        const Divider(height: 20),
        SummaryRow('Subtotal', p.subtotal.format()),
        if (p.spaceDiscount.isPositive)
          SummaryRow('Space discounts', '−${p.spaceDiscount.format()}', valueColor: AppColors.success),
        if (p.customerDiscount.isPositive)
          SummaryRow('Your member discount', '−${p.customerDiscount.format()}', valueColor: AppColors.success),
        if (p.couponDiscount.isPositive)
          SummaryRow(
            'Coupon${p.couponCode == null ? '' : ' (${p.couponCode})'}',
            '−${p.couponDiscount.format()}',
            valueColor: AppColors.success,
          ),
        if (p.fees.isPositive) SummaryRow('Taxes & fees', p.fees.format()),
        const Divider(height: 20),
        SummaryRow('Final total', p.total.format(), bold: true),
        if (showAdvance) SummaryRow('Required advance', p.advanceRequired.format()),
      ],
    );
  }
}

/// Total, paid, refunded, remaining due. "Remaining due" is total minus
/// verified payments; refunds are shown separately as "Refunded".
class PaymentSummary extends StatelessWidget {
  const PaymentSummary({
    super.key,
    required this.total,
    required this.paid,
    required this.due,
    this.refunded = Money.zero,
  });

  final Money total;
  final Money paid;
  final Money due;
  final Money refunded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SummaryRow('Booking total', total.format()),
        SummaryRow('Paid', paid.format(), valueColor: AppColors.success),
        if (refunded.isPositive) SummaryRow('Refunded', refunded.format()),
        SummaryRow(
          'Remaining due',
          due.format(),
          bold: true,
          valueColor: due.isPositive ? AppColors.terracotta : AppColors.success,
        ),
      ],
    );
  }
}

/// One booked space with its own schedule.
class BookingItemTile extends StatelessWidget {
  const BookingItemTile(this.item, {super.key, this.trailing, this.onTap});
  final BookingItem item;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.spaceName, style: text.titleMedium),
                  Text('${item.studioName} · ${item.spaceCode}', style: text.bodySmall),
                  const SizedBox(height: 4),
                  Text(fmtRange(item.schedule), style: text.bodyMedium),
                  Text(fmtDuration(item.schedule.minutes), style: text.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Vertical timeline of status events (booking and refund history).
class TimelineView extends StatelessWidget {
  const TimelineView(this.events, {super.key, this.showNotes = true});
  final List<TimelineEvent> events;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: i == sorted.length - 1 ? AppColors.terracotta : AppColors.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i != sorted.length - 1)
                        Expanded(child: Container(width: 1.5, color: AppColors.line)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sorted[i].title, style: text.titleMedium),
                        Text('${sorted[i].actor} · ${fmtDateTime(sorted[i].at)}', style: text.bodySmall),
                        if (showNotes && (sorted[i].note ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(sorted[i].note!, style: text.bodyMedium),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
