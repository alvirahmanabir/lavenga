import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Refund requests in the signed-in staff member's scope. Managers see their
/// studios' requests; administrators see everything that reached them.
class RefundQueueScreen extends ConsumerStatefulWidget {
  const RefundQueueScreen({super.key});

  @override
  ConsumerState<RefundQueueScreen> createState() => _RefundQueueState();
}

class _RefundQueueState extends ConsumerState<RefundQueueScreen> {
  bool _openOnly = true;

  static const _closed = {
    RefundStatus.refunded,
    RefundStatus.rejectedByManager,
    RefundStatus.rejectedByAdmin,
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    final allowed = PermissionPolicy.can(user, StaffPermission.handleRefunds);
    return Scaffold(
      appBar: AppBar(title: const Text('Refund requests')),
      body: !allowed
          ? const NoAccess(what: 'refund requests')
          : Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: Row(children: [
                  ChoiceChip(
                    label: const Text('Open'),
                    selected: _openOnly,
                    onSelected: (_) => setState(() => _openOnly = true),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_openOnly,
                    onSelected: (_) => setState(() => _openOnly = false),
                  ),
                ]),
              ),
              Expanded(
                child: AsyncBody<List<RefundRequest>>(
                  value: ref.watch(staffRefundsProvider),
                  onRetry: () => ref.invalidate(staffRefundsProvider),
                  data: (all) {
                    final list = [
                      for (final r in all)
                        if (!_openOnly || !_closed.contains(r.status)) r
                    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.assignment_return_outlined,
                        title: 'No refund requests',
                        message: 'Requests appear here when customers submit them.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text('${r.bookingRef} · ${r.requested.format()}'),
                            subtitle: Text('${r.customerName}\n${fmtDate(r.createdAt)}',
                                style: text.bodySmall),
                            isThreeLine: true,
                            trailing: RefundStatusBadge(r.status),
                            onTap: () => context.push('$p/refund/${r.id}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

/// Refund detail with the workflow actions the current role may take:
/// customer request → manager review → admin approval → refund. A refund is
/// shown as completed only when the transaction is verified.
class StaffRefundDetailScreen extends ConsumerWidget {
  const StaffRefundDetailScreen({super.key, required this.refundId});
  final String refundId;

  static String _label(RefundAction a) => switch (a) {
        RefundAction.startReview => 'Start review',
        RefundAction.forward => 'Forward to administrator',
        RefundAction.rejectByManager => 'Reject request',
        RefundAction.approve => 'Approve refund',
        RefundAction.rejectByAdmin => 'Reject request',
        RefundAction.initiate => 'Initiate refund',
        RefundAction.markRefunded => 'Mark refunded (reconcile)',
        RefundAction.markFailed => 'Mark failed',
      };

  static bool _isReject(RefundAction a) =>
      a == RefundAction.rejectByManager || a == RefundAction.rejectByAdmin;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    RefundRequest r,
    RefundAction action,
  ) async {
    final actor = ref.read(currentUserProvider);
    String? note;
    String? customerNote;
    Money? approved;

    if (_isReject(action)) {
      final reason = await askReason(
        context,
        title: 'Reject refund request',
        hint: 'Reason (the customer will see this)',
        confirmLabel: 'Reject',
      );
      if (reason == null) return;
      note = reason;
      customerNote = reason;
    } else if (action == RefundAction.approve) {
      final result = await _askApproval(context, r);
      if (result == null) return;
      approved = result.$1;
      note = result.$2;
    } else if (action == RefundAction.forward) {
      final n = await askReason(
        context,
        title: 'Forward to administrator',
        hint: 'Your review note for the administrator',
        confirmLabel: 'Forward',
        destructive: false,
      );
      if (n == null) return;
      note = n;
    }
    if (!context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(refundRepositoryProvider).perform(
            r.id,
            action,
            actor: actor,
            note: note,
            customerNote: customerNote,
            approvedAmount: approved,
          ),
      success: 'Refund updated',
    );
  }

  Future<(Money, String?)?> _askApproval(BuildContext context, RefundRequest r) {
    final amount = TextEditingController(
        text: (r.requested.minor / 100).toStringAsFixed(r.requested.minor % 100 == 0 ? 0 : 2));
    final note = TextEditingController();
    return showAppSheet<(Money, String?)>(
      context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Approve refund', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Approved amount (৳)',
                  helperText: 'Requested ${r.requested.format()}',
                  errorText: error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  try {
                    final m = Money.parse(amount.text);
                    if (!m.isPositive || m > r.requested) {
                      setState(() => error = 'Between ৳0.01 and ${r.requested.format()}');
                      return;
                    }
                    Navigator.of(ctx).pop((m, note.text.trim().isEmpty ? null : note.text.trim()));
                  } on FormatException {
                    setState(() => error = 'Enter a valid amount');
                  }
                },
                child: const Text('Approve'),
              ),
              const SizedBox(height: AppSpacing.md),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    if (!PermissionPolicy.can(user, StaffPermission.handleRefunds)) {
      return Scaffold(appBar: AppBar(), body: const NoAccess(what: 'refund requests'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Refund request')),
      body: AsyncBody<RefundRequest>(
        value: ref.watch(refundProvider(refundId)),
        onRetry: () => ref.invalidate(refundProvider(refundId)),
        data: (r) {
          final actions = RefundWorkflow.allowedActions(r.status, user.role);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.bookingRef, style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  RefundStatusBadge(r.status),
                ]),
              ),
              SectionCard(
                title: 'Request',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SummaryRow('Customer', r.customerName),
                  SummaryRow('Requested', r.requested.format()),
                  if (r.approved != null) SummaryRow('Approved', r.approved!.format()),
                  SummaryRow('Refunded (verified)', r.refunded.format()),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Customer reason', style: text.labelLarge),
                  Text(r.reason),
                  if ((r.managerNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Manager note', style: text.labelLarge),
                    Text(r.managerNote!),
                  ],
                  if ((r.adminNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Administrator note', style: text.labelLarge),
                    Text(r.adminNote!),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => context.push('$p/booking/${r.bookingId}'),
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Open booking'),
                  ),
                ]),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    for (final a in actions)
                      _isReject(a)
                          ? OutlinedButton(
                              onPressed: () => _act(context, ref, r, a),
                              child: Text(_label(a)),
                            )
                          : FilledButton(
                              onPressed: () => _act(context, ref, r, a),
                              child: Text(_label(a)),
                            ),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Text(
                    user.isManager && r.status == RefundStatus.forwardedToAdmin
                        ? 'Waiting for the administrator.'
                        : 'No action is available to you at this stage.',
                    style: text.bodyMedium,
                  ),
                ),
              if (r.transactions.isNotEmpty)
                SectionCard(
                  title: 'Refund transactions',
                  child: Column(children: [
                    for (final t in r.transactions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.amount.format()),
                        subtitle: Text('${t.gatewayRef} · ${fmtDateTime(t.at)}'),
                        trailing: TransactionStatusBadge(t.status),
                      ),
                  ]),
                ),
              SectionCard(title: 'History', child: TimelineView(r.timeline)),
            ],
          );
        },
      ),
    );
  }
}
