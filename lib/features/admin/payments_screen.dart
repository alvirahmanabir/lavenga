import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/payment_refund.dart';
import 'admin_common.dart';

/// Every payment and gateway attempt, with administrator reconciliation for
/// anything not yet verified. A redirect is never proof of payment.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _q = '';
  TransactionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminPaymentsProvider(_q));
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: AdminBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.sm),
              child: SearchField(
                hint: 'Search by booking reference or customer',
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                    ),
                  ),
                  for (final s in TransactionStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncBody<List<Payment>>(
                value: value,
                onRetry: () => ref.invalidate(adminPaymentsProvider(_q)),
                data: (all) {
                  final list = _status == null
                      ? all
                      : all.where((p) => p.status == _status).toList();
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'No payments found',
                      message: 'Try a different search or status filter.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _PaymentTile(
                      payment: list[i],
                      onTap: () => _open(list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Payment p) {
    showAppSheet<void>(context, builder: (_) => _PaymentSheet(paymentId: p.id));
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap});
  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text('${payment.bookingRef} · ${payment.amount.format()}'),
        subtitle: Text(
            '${payment.kind.name} · ${payment.latest?.method.label ?? 'No method'} · ${fmtDate(payment.createdAt)}',
            style: text.bodySmall),
        trailing: TransactionStatusBadge(payment.status),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerWidget {
  const _PaymentSheet({required this.paymentId});
  final String paymentId;

  Future<void> _reconcile(BuildContext context, WidgetRef ref, bool verified) async {
    final yes = await showConfirmDialog(
      context,
      title: verified ? 'Mark as verified?' : 'Mark as failed?',
      message: verified
          ? 'Only do this after confirming the funds with the gateway or bank. This is recorded in the audit log.'
          : 'The customer will be told the payment did not go through. This is recorded in the audit log.',
      confirmLabel: verified ? 'Mark verified' : 'Mark failed',
      destructive: !verified,
    );
    if (!yes || !context.mounted) return;
    final actor = ref.read(currentUserProvider);
    final ok = await runGuarded(
      context,
      () => ref.read(paymentRepositoryProvider).reconcile(paymentId, verified: verified, actor: actor),
      success: 'Payment reconciled',
    );
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dbVersionProvider);
    final future = ref.watch(_paymentProvider(paymentId));
    return AsyncBody<Payment>(
      value: future,
      loading: const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      data: (p) {
        final canReconcile = !p.isVerified && p.transactions.isNotEmpty;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Payment for ${p.bookingRef}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              SummaryRow('Amount', p.amount.format(), bold: true),
              SummaryRow('Kind', p.kind.name),
              SummaryRow('Status', p.status.label),
              const SectionHeader('Gateway attempts'),
              for (final t in p.transactions.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${t.method.label} · ${t.amount.format()}'),
                  subtitle: Text(
                    '${t.gatewayRef} · ${fmtDateTime(t.at)}'
                    '${t.failureReason == null ? '' : '\n${t.failureReason}'}',
                  ),
                  isThreeLine: t.failureReason != null,
                  trailing: TransactionStatusBadge(t.status),
                ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Open booking',
                kind: AppButtonKind.secondary,
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/a/booking/${p.bookingId}');
                },
              ),
              if (canReconcile) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Reconcile as verified',
                  icon: Icons.verified_outlined,
                  onPressed: () => _reconcile(context, ref, true),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Reconcile as failed',
                  kind: AppButtonKind.text,
                  onPressed: () => _reconcile(context, ref, false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

final _paymentProvider = FutureProvider.autoDispose.family<Payment, String>((ref, id) {
  ref.watch(dbVersionProvider);
  return ref.watch(paymentRepositoryProvider).getPayment(id);
});
