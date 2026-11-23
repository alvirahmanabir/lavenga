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
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/price_and_rating.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/payment_refund.dart';
import '../../../domain/models/promo_social.dart';
import '../../../domain/repositories/engagement_repositories.dart';
import '../../../domain/services/policies.dart';
import 'booking_providers.dart';
import 'common.dart';

const _cardMargin = EdgeInsets.only(bottom: AppSpacing.md);

// ---------------------------------------------------------------------------
// Request a refund
// ---------------------------------------------------------------------------

class RefundRequestScreen extends ConsumerStatefulWidget {
  const RefundRequestScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends ConsumerState<RefundRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(Money max) async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    final amount = Money.parse(_amount.text);
    setState(() => _busy = true);
    final created = await guardedValue<RefundRequest>(
      context,
      () => ref.read(refundRepositoryProvider).request(
            bookingId: widget.bookingId,
            amount: amount,
            reason: _reason.text.trim(),
            actor: user,
          ),
      success: 'Refund request sent',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (created != null) context.pushReplacement('/c/refund/${created.id}');
  }

  @override
  Widget build(BuildContext context) {
    final refundable = ref.watch(refundableProvider(widget.bookingId));
    final booking = valueOf(ref.watch(bookingProvider(widget.bookingId)));
    final settings = valueOf(ref.watch(settingsProvider));
    final now = ref.watch(clockProvider).now();

    return Scaffold(
      appBar: AppBar(title: const Text('Request a refund')),
      body: AsyncBody<Money>(
        value: refundable,
        onRetry: () => ref.invalidate(refundableProvider(widget.bookingId)),
        data: (max) {
          if (!_seeded && max.isPositive) {
            _seeded = true;
            _amount.text = moneyInput(max);
          }
          if (!max.isPositive) {
            return const EmptyState(
              icon: Icons.money_off,
              title: 'Nothing to refund',
              message: 'There is no refundable payment on this booking.',
            );
          }
          final estimate = (booking == null || settings == null)
              ? null
              : CancellationPolicy.refundEstimate(
                  netPaid: max,
                  sessionStart: booking.firstStart,
                  now: now,
                  tiers: settings.refundTiers,
                );
          return CenteredBody(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  SectionCard(
                    margin: _cardMargin,
                    title: booking?.reference ?? 'Booking',
                    child: Column(
                      children: [
                        SummaryRow('Maximum refundable', max.format(), bold: true),
                        if (estimate != null) SummaryRow('Policy estimate', estimate.format()),
                      ],
                    ),
                  ),
                  const Notice(
                    text: 'Your request is reviewed by the studio manager, then approved by an '
                        'administrator. The refund goes back to your original payment method.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Amount to refund (BDT)',
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.payments_outlined,
                    validator: (v) {
                      try {
                        final m = Money.parse(v ?? '');
                        if (!m.isPositive) return 'Enter an amount above zero';
                        if (m > max) return 'Cannot exceed ${max.format()}';
                        return null;
                      } on FormatException {
                        return 'Enter a valid amount';
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Reason',
                    controller: _reason,
                    maxLines: 4,
                    maxLength: 500,
                    validator: (v) => Validators.minLength(v?.trim(), 10, 'Reason'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Submit request',
                    loading: _busy,
                    onPressed: () => _submit(max),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Refund list and detail
// ---------------------------------------------------------------------------

class RefundListScreen extends ConsumerWidget {
  const RefundListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(myRefundsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My refunds')),
      body: AsyncBody<List<RefundRequest>>(
        value: refunds,
        onRetry: () => ref.invalidate(myRefundsProvider),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.currency_exchange,
              title: 'No refund requests',
              message: 'Refund requests you make from a paid booking appear here.',
            );
          }
          final sorted = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return CenteredBody(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final r = sorted[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.push('/c/refund/${r.id}'),
                    title: Text('${r.bookingRef} · ${r.requested.format()}'),
                    subtitle: Text(fmtDate(r.createdAt)),
                    trailing: RefundStatusBadge(r.status),
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

class CustomerRefundDetailScreen extends ConsumerWidget {
  const CustomerRefundDetailScreen({super.key, required this.refundId});
  final String refundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refund = ref.watch(refundProvider(refundId));
    return Scaffold(
      appBar: AppBar(title: const Text('Refund')),
      body: AsyncBody<RefundRequest>(
        value: refund,
        onRetry: () => ref.invalidate(refundProvider(refundId)),
        data: (r) => CenteredBody(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.bookingRef, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  RefundStatusBadge(r.status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                margin: _cardMargin,
                title: 'Amounts',
                child: Column(
                  children: [
                    SummaryRow('Requested', r.requested.format()),
                    if (r.approved != null) SummaryRow('Approved', r.approved!.format()),
                    if (r.refunded.isPositive)
                      SummaryRow('Refunded', r.refunded.format(),
                          bold: true, valueColor: AppColors.success),
                  ],
                ),
              ),
              SectionCard(margin: _cardMargin, title: 'Your reason', child: Text(r.reason)),
              if (r.customerNote != null && r.customerNote!.isNotEmpty)
                SectionCard(
                  margin: _cardMargin,
                  title: 'Message from the studio',
                  child: Text(r.customerNote!),
                ),
              if (r.status == RefundStatus.rejectedByManager ||
                  r.status == RefundStatus.rejectedByAdmin)
                const Notice(
                  text: 'This request was not approved. Contact support if you have questions.',
                  tone: StatusTone.warning,
                ),
              if (r.status == RefundStatus.failed)
                const Notice(
                  text: 'The refund transfer failed and will be retried by our team.',
                  tone: StatusTone.warning,
                ),
              const SizedBox(height: AppSpacing.md),
              // Internal manager/admin notes are intentionally never shown here.
              SectionCard(
                margin: _cardMargin,
                title: 'Progress',
                child: TimelineView(r.timeline, showNotes: false),
              ),
              AppButton(
                label: 'View booking',
                kind: AppButtonKind.secondary,
                onPressed: () => context.push('/c/booking/${r.bookingId}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, required this.bookingId, required this.itemId});
  final String bookingId;
  final String itemId;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _form = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showAppSnack(context, 'Please choose a star rating', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    setState(() => _busy = true);
    final review = await guardedValue<Review>(
      context,
      () => ref.read(reviewRepositoryProvider).submit(
            bookingId: widget.bookingId,
            itemId: widget.itemId,
            rating: _rating,
            comment: _comment.text.trim(),
            actor: user,
          ),
      success: 'Thanks for your review',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (review != null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(widget.bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Write a review')),
      body: AsyncBody<Booking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
        data: (b) {
          BookingItem? item;
          for (final i in b.items) {
            if (i.id == widget.itemId) item = i;
          }
          if (item == null) {
            return const EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'Session not found',
              message: 'This session is no longer available to review.',
            );
          }
          return CenteredBody(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  Text(item.spaceName, style: Theme.of(context).textTheme.headlineSmall),
                  Text('${item.studioName} · ${fmtDate(item.schedule.start)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Your rating', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Semantics(
                          button: true,
                          selected: star <= _rating,
                          label: '$star star${star == 1 ? '' : 's'}',
                          child: IconButton(
                            iconSize: 36,
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => setState(() => _rating = star),
                            icon: Icon(
                              star <= _rating ? Icons.star : Icons.star_border,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Comment',
                    controller: _comment,
                    maxLines: 5,
                    maxLength: 600,
                    validator: (v) => Validators.minLength(v?.trim(), 5, 'Comment'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(label: 'Submit review', loading: _busy, onPressed: _submit),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(myReviewsProvider);
    final eligible = valueOf(ref.watch(eligibleReviewItemsProvider)) ?? const <ReviewableItem>[];
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: AsyncBody<List<Review>>(
        value: reviews,
        onRetry: () => ref.invalidate(myReviewsProvider),
        data: (list) {
          if (list.isEmpty && eligible.isEmpty) {
            return const EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'No reviews yet',
              message: 'After a session is completed you can review the space here.',
            );
          }
          return CenteredBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                if (eligible.isNotEmpty) ...[
                  Text('Waiting for your review', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final e in eligible)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(e.item.spaceName),
                        subtitle: Text(fmtDate(e.item.schedule.start)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/c/review/${e.booking.id}/${e.item.id}'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (list.isNotEmpty) Text('Published reviews', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final r in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingStars(rating: r.rating.toDouble(), count: 1),
                          const SizedBox(height: AppSpacing.sm),
                          Text(r.comment),
                          const SizedBox(height: AppSpacing.sm),
                          Text(fmtDate(r.createdAt), style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
