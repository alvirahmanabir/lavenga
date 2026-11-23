import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/repositories/booking_repositories.dart';
import '../../../domain/services/pricing_service.dart';
import '../../cart/cart_notifier.dart';
import 'booking_providers.dart';
import 'common.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _coupon;

  @override
  void initState() {
    super.initState();
    _coupon = TextEditingController(text: ref.read(cartCouponProvider));
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final code = ref.watch(cartCouponProvider);
    final text = Theme.of(context).textTheme;

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your cart')),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Add one or more spaces with their own date and time. You can book several at once.',
          actionLabel: 'Explore spaces',
          onAction: () => context.go('/c/explore'),
        ),
      );
    }

    final quote = ref.watch(cartQuoteProvider(code));
    final settings = valueOf(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(title: Text('Your cart (${lines.length})')),
      body: Column(
        children: [
          Expanded(
            child: CenteredBody(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  Notice(
                    text:
                        'Nothing is reserved yet. When you check out, slots are held for ${settings?.holdMinutes ?? 10} minutes while you pay.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final line in lines) ...[
                    _CartLineCard(line: line),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextButton.icon(
                    onPressed: () => context.go('/c/explore'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add another space'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Coupon code', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Enter code',
                          controller: _coupon,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (v) => ref.read(cartCouponProvider.notifier).set(v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppButton(
                          label: code.isEmpty ? 'Apply' : 'Update',
                          kind: AppButtonKind.secondary,
                          expand: false,
                          onPressed: () => ref.read(cartCouponProvider.notifier).set(_coupon.text),
                        ),
                      ),
                    ],
                  ),
                  if (code.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _coupon.clear();
                        ref.read(cartCouponProvider.notifier).set('');
                      },
                      child: const Text('Remove coupon'),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AsyncBody<QuoteResult>(
                    value: quote,
                    loading: const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    onRetry: () => ref.invalidate(cartQuoteProvider(code)),
                    data: (q) => Column(
                      children: [
                        if (q.coupon != null) ...[
                          Notice(
                            tone: q.coupon!.valid ? StatusTone.success : StatusTone.warning,
                            text: q.coupon!.message,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        SectionCard(
                          title: 'Estimated price',
                          child: PricingSummary(q.pricing),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Prices are estimates until the studio system confirms your order at checkout.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyBar(
            child: AppButton(
              label: 'Continue to checkout',
              icon: Icons.lock_outline,
              onPressed: () => context.push('/c/checkout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineCard extends ConsumerWidget {
  const _CartLineCard({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceProvider(line.spaceId));
    final text = Theme.of(context).textTheme;
    final s = valueOf<StudioSpace>(space);
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: AppImage(
              url: s != null && s.images.isNotEmpty ? s.images.first : null,
              radius: AppRadii.field,
              semanticLabel: s?.name,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s?.name ?? 'Loading…', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(fmtRange(line.schedule), style: text.bodyMedium),
                Text(fmtDuration(line.schedule.minutes), style: text.bodySmall),
                if (line.notes.isNotEmpty) Text('Note: ${line.notes}', style: text.bodySmall),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => context.push('/c/schedule/${line.spaceId}'),
                      child: const Text('Change time'),
                    ),
                    TextButton(
                      onPressed: () => ref.read(cartProvider.notifier).remove(line.id),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notes = TextEditingController();
  bool _agreed = false;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final user = ref.read(currentUserProvider);
    final lines = ref.read(cartProvider);
    final code = ref.read(cartCouponProvider);
    setState(() => _busy = true);
    final booking = await guardedValue<Booking>(
      context,
      () => ref.read(bookingRepositoryProvider).createOrder(
            customer: user,
            lines: lines,
            couponCode: code.isEmpty ? null : code,
            notes: _notes.text.trim(),
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (booking == null) return;
    ref.read(cartProvider.notifier).clear();
    ref.read(cartCouponProvider.notifier).set('');
    context.go('/c/pay/${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final code = ref.watch(cartCouponProvider);
    final quote = ref.watch(cartQuoteProvider(code));
    final settings = valueOf(ref.watch(settingsProvider));
    final text = Theme.of(context).textTheme;

    if (lines.isEmpty && !_busy) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing to check out',
          message: 'Your cart is empty.',
          actionLabel: 'Explore spaces',
          onAction: () => context.go('/c/explore'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Column(
        children: [
          Expanded(
            child: CenteredBody(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  SectionCard(
                    title: 'Sessions',
                    child: Column(
                      children: [
                        for (final l in lines) _CheckoutLine(line: l),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Notes for the studio (optional)',
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 400,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AsyncBody<QuoteResult>(
                    value: quote,
                    loading: const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    onRetry: () => ref.invalidate(cartQuoteProvider(code)),
                    data: (q) => SectionCard(
                      title: 'Price summary',
                      child: PricingSummary(q.pricing),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Notice(
                    text:
                        'Placing the order holds your slots for ${settings?.holdMinutes ?? 10} minutes. Your booking is not confirmed until you pay and the studio confirms it. At the next step you can pay the advance or the full amount.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    title: Text('I agree to the terms and cancellation policy', style: text.bodyMedium),
                    subtitle: GestureDetector(
                      onTap: () => context.push('/c/policies'),
                      child: Text(
                        'Read policies',
                        style: text.bodySmall?.copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyBar(
            child: AppButton(
              label: 'Place order & hold slots',
              icon: Icons.timer_outlined,
              loading: _busy,
              onPressed: (!_agreed || _busy || !quote.hasValue) ? null : _place,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLine extends ConsumerWidget {
  const _CheckoutLine({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = valueOf<StudioSpace>(ref.watch(spaceProvider(line.spaceId)));
    return InfoRow(Icons.event, '${s?.name ?? 'Space'}\n${fmtRange(line.schedule)}');
  }
}
