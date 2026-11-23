import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/payment_refund.dart';
import '../../../domain/services/payment_calculator.dart';
import '../../../domain/services/policies.dart';
import 'booking_providers.dart';
import 'common.dart';

// ---------------------------------------------------------------------------
// My bookings
// ---------------------------------------------------------------------------

enum _BookingTab { upcoming, pending, past }

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  _BookingTab _tab = _BookingTab.upcoming;

  bool _matches(Booking b) {
    switch (_tab) {
      case _BookingTab.pending:
        return b.status == BookingStatus.pendingReview;
      case _BookingTab.upcoming:
        return b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress;
      case _BookingTab.past:
        return b.status.isClosed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(myBookingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
        actions: [
          IconButton(
            tooltip: 'Refunds',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => context.push('/c/refunds'),
          ),
        ],
      ),
      body: CenteredBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SegmentedButton<_BookingTab>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _BookingTab.upcoming, label: Text('Upcoming')),
                  ButtonSegment(value: _BookingTab.pending, label: Text('Pending')),
                  ButtonSegment(value: _BookingTab.past, label: Text('Past')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            Expanded(
              child: AsyncBody<List<Booking>>(
                value: bookings,
                onRetry: () => ref.invalidate(myBookingsProvider),
                data: (all) {
                  final list = all.where(_matches).toList()
                    ..sort((a, b) => _tab == _BookingTab.past
                        ? b.firstStart.compareTo(a.firstStart)
                        : a.firstStart.compareTo(b.firstStart));
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.event_busy,
                      title: 'No bookings here',
                      message: _tab == _BookingTab.past
                          ? 'Completed and closed bookings appear here.'
                          : 'Find a space and book your first session.',
                      actionLabel: 'Explore spaces',
                      onAction: () => context.go('/c/explore'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xl),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _BookingCard(booking: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = booking.items.first;
    final more = booking.items.length - 1;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.push('/c/booking/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(booking.reference, style: text.labelLarge)),
                  BookingStatusBadge(booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                more > 0 ? '${first.spaceName} + $more more' : first.spaceName,
                style: text.titleMedium,
              ),
              Text(first.studioName, style: text.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(Icons.event, fmtRange(first.schedule)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text(booking.total.format(), style: text.titleMedium)),
                  PaymentStatusBadge(booking.paymentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking detail
// ---------------------------------------------------------------------------

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final payments = valueOf(ref.watch(bookingPaymentsProvider(bookingId))) ?? const <Payment>[];
    final refunds = (valueOf(ref.watch(myRefundsProvider)) ?? const <RefundRequest>[])
        .where((r) => r.bookingId == bookingId)
        .toList();
    final user = ref.watch(currentUserProvider);
    final settings = valueOf(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: AsyncBody<Booking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) {
          final now = ref.watch(clockProvider).now();
          final paid = PaymentCalculator.verifiedPaid(payments);
          final refunded = refunds.fold<Money>(Money.zero, (s, r) => s + r.refunded);
          final due = PaymentCalculator.remainingDue(b.total, payments);
          final netPaid = PaymentCalculator.netPaid(payments, refunded);
          final openRequested = refunds
              .where((r) => !r.status.isTerminal)
              .fold<Money>(Money.zero, (s, r) => s + r.requested);
          final canRefund = CancellationPolicy.canRequestRefund(
            booking: b,
            netPaid: netPaid,
            alreadyRequestedOpen: openRequested,
          );
          final holdActive = b.holdExpiresAt != null &&
              b.status == BookingStatus.pendingReview &&
              b.paymentStatus == PaymentStatus.unpaid;
          final holdLive = holdActive && now.isBefore(b.holdExpiresAt!);
          final canPay = !b.status.isClosed &&
              due.isPositive &&
              b.status != BookingStatus.inProgress &&
              (b.paymentStatus != PaymentStatus.unpaid || holdLive);
          final estimate = settings == null
              ? null
              : CancellationPolicy.refundEstimate(
                  netPaid: netPaid,
                  sessionStart: b.firstStart,
                  now: now,
                  tiers: settings.refundTiers,
                );

          return CenteredBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(b.reference, style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    BookingStatusBadge(b.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [PaymentStatusBadge(b.paymentStatus)]),
                const SizedBox(height: AppSpacing.lg),
                if (holdActive) ...[
                  HoldCountdown(expiresAt: b.holdExpiresAt!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (b.status == BookingStatus.pendingReview && b.paymentStatus != PaymentStatus.unpaid)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Notice(
                      text: 'Payment received. Your booking is awaiting confirmation from the studio. '
                          'It is not confirmed until a manager approves it.',
                    ),
                  ),
                if (b.cancelReason != null && b.cancelReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Notice(text: 'Reason: ${b.cancelReason}', tone: StatusTone.warning),
                  ),
                SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                  title: 'Sessions',
                  child: Column(
                    children: [
                      for (final item in b.items)
                        BookingItemTile(
                          item,
                          onTap: () => context.push('/c/space/${item.spaceId}'),
                          trailing: b.status == BookingStatus.completed
                              ? TextButton(
                                  onPressed: () =>
                                      context.push('/c/review/${b.id}/${item.id}'),
                                  child: const Text('Review'),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                if (b.notes.isNotEmpty)
                  SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), title: 'Your notes', child: Text(b.notes)),
                SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), title: 'Price', child: PricingSummary(b.pricing)),
                SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                  title: 'Payment',
                  child: Column(
                    children: [
                      PaymentSummary(total: b.total, paid: paid, due: due, refunded: refunded),
                      if (refunded.isPositive) SummaryRow('Net paid', netPaid.format()),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push('/c/booking/${b.id}/payments'),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Payment history'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (refunds.isNotEmpty)
                  SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                    title: 'Refund requests',
                    child: Column(
                      children: [
                        for (final r in refunds)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.requested.format()),
                            subtitle: Text(fmtDate(r.createdAt)),
                            trailing: RefundStatusBadge(r.status),
                            onTap: () => context.push('/c/refund/${r.id}'),
                          ),
                      ],
                    ),
                  ),
                SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), title: 'Timeline', child: TimelineView(b.timeline)),
                if (canRefund && estimate != null && estimate.isPositive)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Notice(
                      text: 'Estimated refund under the policy: ${estimate.format()}. '
                          'The final amount is decided after review.',
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (canPay)
                  AppButton(
                    label: b.paymentStatus == PaymentStatus.unpaid
                        ? 'Pay now'
                        : 'Pay remaining ${due.format()}',
                    icon: Icons.payments_outlined,
                    onPressed: () => context.push('/c/pay/${b.id}'),
                  ),
                if (canRefund) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Request refund',
                    kind: AppButtonKind.secondary,
                    icon: Icons.currency_exchange,
                    onPressed: () => context.push('/c/booking/${b.id}/refund'),
                  ),
                ],
                if (CancellationPolicy.canCustomerCancel(b)) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Cancel booking',
                    kind: AppButtonKind.secondary,
                    icon: Icons.close,
                    onPressed: () => _cancel(context, ref, b, user),
                  ),
                ] else if (b.status == BookingStatus.confirmed) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Notice(
                    text: 'Confirmed bookings cannot be cancelled in the app. '
                        'Contact support or request a refund if you have paid.',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Get help with this booking',
                  kind: AppButtonKind.text,
                  icon: Icons.support_agent,
                  onPressed: () => context.push('/c/support/new?booking=${b.id}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b, user) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel this booking?',
      message: 'Held slots are released. If you already paid, request a refund afterwards.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(bookingRepositoryProvider).cancelByCustomer(b.id, actor: user),
      success: 'Booking cancelled',
    );
  }
}

// ---------------------------------------------------------------------------
// Payment history and transaction detail
// ---------------------------------------------------------------------------

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(bookingPaymentsProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: AsyncBody<List<Payment>>(
        value: payments,
        onRetry: () => ref.invalidate(bookingPaymentsProvider(bookingId)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long,
              title: 'No payments yet',
              message: 'Payments you make for this booking will be listed here.',
            );
          }
          return CenteredBody(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final p = list[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.push('/c/payment/${p.id}'),
                    title: Text('${_kindLabel(p.kind)} · ${p.amount.format()}'),
                    subtitle: Text(fmtDateTime(p.createdAt)),
                    trailing: TransactionStatusBadge(p.status),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _kindLabel(PaymentKind k) => switch (k) {
      PaymentKind.full => 'Full payment',
      PaymentKind.advance => 'Advance',
      PaymentKind.balance => 'Balance',
    };

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = ref.watch(paymentProvider(paymentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: AsyncBody<Payment>(
        value: payment,
        onRetry: () => ref.invalidate(paymentProvider(paymentId)),
        data: (p) => CenteredBody(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              // A receipt is only shown once the backend verified the payment.
              if (p.isVerified)
                const Notice(
                  text: 'Verified payment receipt',
                  tone: StatusTone.success,
                  icon: Icons.verified_outlined,
                )
              else
                const Notice(
                  text: 'A receipt is issued only after the payment is verified.',
                  tone: StatusTone.warning,
                ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                title: 'Details',
                child: Column(
                  children: [
                    SummaryRow('Booking', p.bookingRef),
                    SummaryRow('Type', _kindLabel(p.kind)),
                    SummaryRow('Amount', p.amount.format(), bold: true),
                    SummaryRow('Status', p.status.label),
                    SummaryRow('Created', fmtDateTime(p.createdAt)),
                  ],
                ),
              ),
              SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                title: 'Attempts',
                child: Column(
                  children: [
                    for (final t in p.transactions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${t.method.label} · ${t.amount.format()}'),
                        subtitle: Text(
                          '${fmtDateTime(t.at)}\nRef ${t.gatewayRef}'
                          '${t.failureReason == null ? '' : '\n${t.failureReason}'}',
                        ),
                        isThreeLine: true,
                        trailing: TransactionStatusBadge(t.status),
                      ),
                  ],
                ),
              ),
              AppButton(
                label: 'View booking',
                kind: AppButtonKind.secondary,
                onPressed: () => context.push('/c/booking/${p.bookingId}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
