import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/payment_refund.dart';
import '../../../domain/repositories/booking_repositories.dart';
import '../../../domain/services/payment_calculator.dart';
import 'booking_providers.dart';
import 'common.dart';

// ---------------------------------------------------------------------------
// Choose amount and method
// ---------------------------------------------------------------------------

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  PaymentKind _kind = PaymentKind.advance;
  PaymentMethod _method = PaymentMethod.bkash;
  bool _busy = false;

  IconData _icon(PaymentMethod m) => switch (m) {
        PaymentMethod.bkash => Icons.phone_android,
        PaymentMethod.nagad => Icons.phone_android,
        PaymentMethod.card => Icons.credit_card,
        PaymentMethod.bank => Icons.account_balance,
      };

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final payments =
        valueOf(ref.watch(bookingPaymentsProvider(widget.bookingId))) ?? const <Payment>[];
    final settings = valueOf(ref.watch(settingsProvider));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: AsyncBody<Booking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
        data: (b) {
          final due = PaymentCalculator.remainingDue(b.total, payments);
          final hasPaid = PaymentCalculator.verifiedPaid(payments).isPositive;
          final advance = settings == null
              ? b.pricing.advanceRequired
              : PaymentCalculator.advanceAmount(b.total, settings.advanceBp);
          // First payment: advance or full. Later payments: balance only.
          final kinds = hasPaid
              ? [PaymentKind.balance]
              : (advance < due ? [PaymentKind.advance, PaymentKind.full] : [PaymentKind.full]);
          final kind = kinds.contains(_kind) ? _kind : kinds.first;
          final amount = kind == PaymentKind.advance ? advance : due;
          final expired = b.status.isClosed;

          return CenteredBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                if (b.holdExpiresAt != null &&
                    b.status == BookingStatus.pendingReview &&
                    b.paymentStatus == PaymentStatus.unpaid) ...[
                  HoldCountdown(expiresAt: b.holdExpiresAt!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (expired)
                  const Notice(
                    text: 'This booking is no longer open for payment.',
                    tone: StatusTone.error,
                  ),
                SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                  title: b.reference,
                  child: PaymentSummary(
                    total: b.total,
                    paid: PaymentCalculator.verifiedPaid(payments),
                    due: due,
                  ),
                ),
                const SectionHeader('What would you like to pay?',
                    padding: EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm)),
                for (final k in kinds)
                  ChoiceTile(
                    selected: k == kind,
                    title: switch (k) {
                      PaymentKind.advance => 'Advance',
                      PaymentKind.full => 'Full amount',
                      PaymentKind.balance => 'Remaining balance',
                    },
                    subtitle: k == PaymentKind.advance
                        ? 'Pay the rest later'
                        : 'Settles the booking',
                    trailing: Text(
                      (k == PaymentKind.advance ? advance : due).format(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => setState(() => _kind = k),
                  ),
                const SectionHeader('Payment method',
                    padding: EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.lg)),
                for (final m in PaymentMethod.values)
                  ChoiceTile(
                    selected: m == _method,
                    title: m.label,
                    trailing: Icon(_icon(m)),
                    onTap: () => setState(() => _method = m),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const Notice(
                  text: 'You will complete payment on the secure gateway page. '
                      'Your booking is only marked paid after the payment is verified.',
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Pay ${amount.format()}',
                  icon: Icons.lock_outline,
                  loading: _busy,
                  onPressed: expired || !amount.isPositive
                      ? null
                      : () => _pay(context, user, kind),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pay(BuildContext context, user, PaymentKind kind) async {
    setState(() => _busy = true);
    final payment = await guardedValue<Payment>(
      context,
      () => ref.read(paymentRepositoryProvider).startPayment(
            bookingId: widget.bookingId,
            kind: kind,
            method: _method,
            actor: user,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (payment != null) {
      context.pushReplacement('/c/pay/${widget.bookingId}/processing?p=${payment.id}');
    }
  }
}

// ---------------------------------------------------------------------------
// Processing: simulated gateway
// ---------------------------------------------------------------------------

class PaymentProcessingScreen extends ConsumerStatefulWidget {
  const PaymentProcessingScreen({super.key, required this.bookingId, required this.paymentId});
  final String bookingId;
  final String paymentId;

  @override
  ConsumerState<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends ConsumerState<PaymentProcessingScreen> {
  bool _busy = false;

  Future<void> _run(GatewayOutcome outcome) async {
    setState(() => _busy = true);
    final p = await guardedValue<Payment>(
      context,
      () => ref.read(paymentRepositoryProvider).simulateGateway(widget.paymentId, outcome),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (p == null) return;
    final base = '/c/pay/${widget.bookingId}';
    switch (p.status) {
      case TransactionStatus.verified:
      case TransactionStatus.pendingVerification:
        context.go('$base/success?p=${p.id}');
      default:
        context.go('$base/failure?p=${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentProvider(widget.paymentId));
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Secure payment'), automaticallyImplyLeading: false),
        body: AsyncBody<Payment>(
          value: payment,
          data: (p) => CenteredBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: _busy
                      ? const SizedBox(width: 56, height: 56, child: CircularProgressIndicator())
                      : const Icon(Icons.lock_outline, size: 56),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _busy ? 'Verifying your payment…' : 'Gateway (simulated)',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${p.amount.format()} via ${p.latest?.method.label ?? ''} for ${p.bookingRef}',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Notice(
                  text: 'Demo only. In production this step opens the SSLCommerz hosted page, '
                      'and the result is verified by the server. Choose an outcome to simulate.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Simulate successful payment',
                  loading: _busy,
                  onPressed: _busy ? null : () => _run(GatewayOutcome.success),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Simulate failed payment',
                  kind: AppButtonKind.secondary,
                  onPressed: _busy ? null : () => _run(GatewayOutcome.failure),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Simulate cancelled by me',
                  kind: AppButtonKind.secondary,
                  onPressed: _busy ? null : () => _run(GatewayOutcome.cancelled),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Simulate timeout',
                  kind: AppButtonKind.text,
                  onPressed: _busy ? null : () => _run(GatewayOutcome.timeout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result screens
// ---------------------------------------------------------------------------

class PaymentSuccessScreen extends ConsumerWidget {
  const PaymentSuccessScreen({super.key, required this.bookingId, required this.paymentId});
  final String bookingId;
  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payment = valueOf(ref.watch(paymentProvider(paymentId)));
    final booking = valueOf(ref.watch(bookingProvider(bookingId)));
    final text = Theme.of(context).textTheme;
    final verified = payment?.isVerified ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), automaticallyImplyLeading: false),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(
              verified ? Icons.check_circle : Icons.hourglass_top,
              size: 72,
              color: verified ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              verified ? 'Payment verified' : 'Payment received, awaiting verification',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              booking?.status == BookingStatus.confirmed
                  ? 'Your booking is confirmed.'
                  : 'Your booking is awaiting confirmation from the studio. '
                      'You will be notified when it is approved.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (payment != null)
              SectionCard(margin: const EdgeInsets.only(bottom: AppSpacing.md), 
                title: verified ? 'Receipt' : 'Payment',
                child: Column(
                  children: [
                    SummaryRow('Booking', payment.bookingRef),
                    SummaryRow('Amount', payment.amount.format(), bold: true),
                    SummaryRow('Method', payment.latest?.method.label ?? '-'),
                    SummaryRow('Reference', payment.latest?.gatewayRef ?? '-'),
                    SummaryRow('Time', fmtDateTime(payment.latest?.at ?? payment.createdAt)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View booking',
              onPressed: () => context.go('/c/booking/$bookingId'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Back to home',
              kind: AppButtonKind.text,
              onPressed: () => context.go('/c/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentFailureScreen extends ConsumerStatefulWidget {
  const PaymentFailureScreen({super.key, required this.bookingId, required this.paymentId});
  final String bookingId;
  final String paymentId;

  @override
  ConsumerState<PaymentFailureScreen> createState() => _PaymentFailureScreenState();
}

class _PaymentFailureScreenState extends ConsumerState<PaymentFailureScreen> {
  bool _busy = false;

  Future<void> _retry(Payment p) async {
    setState(() => _busy = true);
    final next = await guardedValue<Payment>(
      context,
      () => ref
          .read(paymentRepositoryProvider)
          .retry(p.id, p.latest?.method ?? PaymentMethod.bkash),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (next != null) {
      context.pushReplacement('/c/pay/${widget.bookingId}/processing?p=${next.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = valueOf(ref.watch(paymentProvider(widget.paymentId)));
    final booking = valueOf(ref.watch(bookingProvider(widget.bookingId)));
    final text = Theme.of(context).textTheme;
    final cancelled = payment?.status == TransactionStatus.cancelled;
    final canRetry = booking != null && !booking.status.isClosed;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), automaticallyImplyLeading: false),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(cancelled ? Icons.cancel_outlined : Icons.error_outline,
                size: 72, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              cancelled ? 'Payment cancelled' : 'Payment did not go through',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You were not charged for this attempt. ${payment?.latest?.failureReason ?? ''}'.trim(),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (booking?.holdExpiresAt != null &&
                booking!.status == BookingStatus.pendingReview &&
                booking.paymentStatus == PaymentStatus.unpaid)
              HoldCountdown(expiresAt: booking.holdExpiresAt!),
            const SizedBox(height: AppSpacing.xl),
            if (payment != null && canRetry)
              AppButton(
                label: 'Try again',
                icon: Icons.refresh,
                loading: _busy,
                onPressed: () => _retry(payment),
              ),
            const SizedBox(height: AppSpacing.md),
            if (canRetry)
              AppButton(
                label: 'Choose another method',
                kind: AppButtonKind.secondary,
                onPressed: () => context.pushReplacement('/c/pay/${widget.bookingId}'),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'View booking',
              kind: AppButtonKind.text,
              onPressed: () => context.go('/c/booking/${widget.bookingId}'),
            ),
          ],
        ),
      ),
    );
  }
}
