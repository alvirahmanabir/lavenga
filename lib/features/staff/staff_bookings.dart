import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/repositories/booking_repositories.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Booking list for managers (scoped) and administrators (all orders).
/// Used as a tab, so [embedded] screens show no back button.
class StaffBookingsScreen extends ConsumerWidget {
  const StaffBookingsScreen({super.key, this.embedded = true});
  final bool embedded;

  static const _statusChips = [
    BookingStatus.pendingReview,
    BookingStatus.confirmed,
    BookingStatus.inProgress,
    BookingStatus.completed,
    BookingStatus.cancelled,
    BookingStatus.rejected,
    BookingStatus.expired,
    BookingStatus.noShow,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(staffBookingFilterProvider);
    final notifier = ref.read(staffBookingFilterProvider.notifier);
    final p = ref.watch(rolePrefixProvider);
    final bookings = ref.watch(staffBookingsProvider);
    final text = Theme.of(context).textTheme;

    BookingFilter rebuild({
      String? textValue,
      Set<BookingStatus>? statuses,
      Set<PaymentStatus>? payments,
      DateTime? from,
      DateTime? to,
      bool clearDates = false,
    }) =>
        BookingFilter(
          text: textValue ?? filter.text,
          statuses: statuses ?? filter.statuses,
          paymentStatuses: payments ?? filter.paymentStatuses,
          from: clearDates ? null : (from ?? filter.from),
          to: clearDates ? null : (to ?? filter.to),
          customerId: filter.customerId,
        );

    final hasFilters = filter.statuses.isNotEmpty ||
        filter.paymentStatuses.isNotEmpty ||
        filter.from != null ||
        filter.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(ref.watch(sessionProvider).role == UserRole.admin ? 'Orders' : 'Bookings'),
        actions: [
          IconButton(
            tooltip: 'Date range',
            icon: Icon(filter.from == null ? Icons.date_range : Icons.event_available),
            onPressed: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
              );
              if (range == null) return;
              notifier.set(rebuild(
                from: fromStudioLocal(range.start.year, range.start.month, range.start.day),
                to: fromStudioLocal(range.end.year, range.end.month, range.end.day)
                    .add(const Duration(days: 1)),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
            child: SearchField(
              hint: 'Reference, customer or space',
              initialValue: filter.text,
              onChanged: (v) => notifier.set(rebuild(textValue: v)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              children: [
                for (final s in _statusChips)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: filter.statuses.contains(s),
                      onSelected: (on) {
                        final next = {...filter.statuses};
                        on ? next.add(s) : next.remove(s);
                        notifier.set(rebuild(statuses: next));
                      },
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              children: [
                for (final s in const [
                  PaymentStatus.unpaid,
                  PaymentStatus.pendingVerification,
                  PaymentStatus.partiallyPaid,
                  PaymentStatus.paid,
                  PaymentStatus.partiallyRefunded,
                  PaymentStatus.refunded,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: filter.paymentStatuses.contains(s),
                      onSelected: (on) {
                        final next = {...filter.paymentStatuses};
                        on ? next.add(s) : next.remove(s);
                        notifier.set(rebuild(payments: next));
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (filter.from != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Row(children: [
                Expanded(
                  child: Text(
                    'From ${fmtDate(filter.from!)}${filter.to == null ? '' : ' to ${fmtDate(filter.to!.subtract(const Duration(days: 1)))}'}',
                    style: text.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.set(rebuild(clearDates: true)),
                  child: const Text('Clear dates'),
                ),
              ]),
            ),
          Expanded(
            child: AsyncBody<List<Booking>>(
              value: bookings,
              onRetry: () => ref.invalidate(staffBookingsProvider),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_busy,
                    title: 'No bookings found',
                    message: hasFilters
                        ? 'Nothing matches these filters.'
                        : 'Bookings will appear here as customers place them.',
                    actionLabel: hasFilters ? 'Clear filters' : null,
                    onAction: hasFilters ? () => notifier.set(const BookingFilter()) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(staffBookingsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => StaffBookingCard(
                      booking: list[i],
                      onTap: () => context.push('$p/booking/${list[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
