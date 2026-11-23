import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Booking detail for managers and administrators. Every action goes through
/// the repository (which re-checks scope, permission and transition rules);
/// the buttons shown here are only a convenience.
class StaffBookingDetailScreen extends ConsumerWidget {
  const StaffBookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: AsyncBody<Booking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) => _Body(booking: b),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.booking});
  final Booking booking;

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    BookingStatus to, {
    bool needsReason = false,
    String? title,
  }) async {
    final actor = ref.read(currentUserProvider);
    String? reason;
    if (needsReason) {
      reason = await askReason(
        context,
        title: title ?? 'Reason',
        hint: 'Shown to the customer and kept in the audit log',
      );
      if (reason == null) return;
    } else {
      final ok = await showConfirmDialog(
        context,
        title: title ?? 'Update booking?',
        message: 'Move ${booking.reference} to "${to.label}".',
      );
      if (!ok) return;
    }
    if (!context.mounted) return;
    await runGuarded(
      context,
      () async {
        await ref
            .read(bookingRepositoryProvider)
            .updateStatus(booking.id, to, actor: actor, reason: reason);
        ref.read(dbVersionProvider.notifier).bump();
      },
      success: 'Booking updated to ${to.label}',
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showAppSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Internal note', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Only staff can see this note.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save note'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !context.mounted) return;
    final actor = ref.read(currentUserProvider);
    await runGuarded(
      context,
      () async {
        await ref.read(bookingRepositoryProvider).addInternalNote(booking.id, text, actor: actor);
        ref.read(dbVersionProvider.notifier).bump();
      },
      success: 'Note added',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    final b = booking;
    final canConfirm = PermissionPolicy.can(user, StaffPermission.confirmBookings);
    final canCancel = PermissionPolicy.can(user, StaffPermission.cancelBookings);
    final canPayments = PermissionPolicy.can(user, StaffPermission.viewPayments);
    final canRefunds = PermissionPolicy.can(user, StaffPermission.handleRefunds);
    final next = BookingTransitions.from(b.status);

    final actions = <Widget>[
      if (canConfirm && next.contains(BookingStatus.confirmed))
        FilledButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.confirmed,
              title: 'Confirm booking?'),
          icon: const Icon(Icons.check),
          label: const Text('Confirm'),
        ),
      if (canConfirm && next.contains(BookingStatus.rejected))
        OutlinedButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.rejected,
              needsReason: true, title: 'Reject booking'),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
        ),
      if (canConfirm && next.contains(BookingStatus.inProgress))
        OutlinedButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.inProgress,
              title: 'Mark in progress?'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start session'),
        ),
      if (canConfirm && next.contains(BookingStatus.completed))
        OutlinedButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.completed,
              title: 'Mark completed?'),
          icon: const Icon(Icons.done_all),
          label: const Text('Complete'),
        ),
      if (canConfirm && next.contains(BookingStatus.noShow))
        OutlinedButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.noShow,
              title: 'Mark as no-show?'),
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('No-show'),
        ),
      if (canCancel && CancellationPolicy.canStaffCancel(b))
        TextButton.icon(
          onPressed: () => _transition(context, ref, BookingStatus.cancelled,
              needsReason: true, title: 'Cancel booking'),
          icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
          label: Text('Cancel booking',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.reference, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              BookingStatusBadge(b.status),
              PaymentStatusBadge(b.paymentStatus),
            ]),
            if (b.status == BookingStatus.pendingReview && b.holdExpiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Payment hold until ${fmtDateTime(b.holdExpiresAt!)}', style: text.bodySmall),
            ],
            if (b.cancelReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Reason: ${b.cancelReason}', style: text.bodyMedium),
            ],
          ]),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions),
          )
        else
          const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Customer',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.customerName, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (PermissionPolicy.can(user, StaffPermission.viewCustomers))
              TextButton.icon(
                onPressed: () => context.push('$p/customer/${b.customerId}'),
                icon: const Icon(Icons.person_outline),
                label: const Text('View customer'),
              ),
          ]),
        ),
        SectionCard(
          title: 'Spaces and schedule',
          child: Column(children: [for (final i in b.items) BookingItemTile(i)]),
        ),
        if (b.notes.isNotEmpty)
          SectionCard(title: 'Customer notes', child: Text(b.notes)),
        SectionCard(title: 'Pricing', child: PricingSummary(b.pricing)),
        if (canPayments) _PaymentsCard(booking: b),
        if (canRefunds || user.isAdmin) _RefundsCard(booking: b),
        SectionCard(
          title: 'Internal notes',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (b.internalNotes.isEmpty)
              Text('No internal notes yet.', style: text.bodySmall),
            for (final n in b.internalNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.text),
                  Text('${n.authorName} · ${fmtDateTime(n.at)}', style: text.bodySmall),
                ]),
              ),
            TextButton.icon(
              onPressed: () => _addNote(context, ref),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Add note'),
            ),
          ]),
        ),
        SectionCard(title: 'History', child: TimelineView(b.timeline)),
      ],
    );
  }
}

class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(bookingPaymentsProvider(booking.id));
    final refunds = ref.watch(bookingRefundsProvider(booking.id));
    return SectionCard(
      title: 'Payments',
      child: payments.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => const Text('Could not load payments.'),
        data: (list) {
          final paid = list.fold(Money.zero, (a, x) => a + x.verifiedAmount);
          final refunded = (refunds.maybeWhen(data: (d) => d, orElse: () => const <RefundRequest>[]))
              .fold(Money.zero, (a, r) => a + r.refunded);
          final due = (booking.total - paid).clampMin(Money.zero);
          return Column(children: [
            PaymentSummary(total: booking.total, paid: paid, due: due, refunded: refunded),
            const SizedBox(height: AppSpacing.sm),
            for (final pay in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${pay.kind.name} · ${pay.amount.format()}'),
                subtitle: Text(fmtDateTime(pay.createdAt)),
                trailing: TransactionStatusBadge(pay.status),
              ),
            if (list.isEmpty) const Text('No payment attempts yet.'),
          ]);
        },
      ),
    );
  }
}

class _RefundsCard extends ConsumerWidget {
  const _RefundsCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(rolePrefixProvider);
    final refunds = ref.watch(bookingRefundsProvider(booking.id));
    final list = refunds.maybeWhen(data: (d) => d, orElse: () => const <RefundRequest>[]);
    if (list.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Refund requests',
      child: Column(children: [
        for (final r in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Requested ${r.requested.format()}'),
            trailing: RefundStatusBadge(r.status),
            onTap: () => context.push('$p/refund/${r.id}'),
          ),
      ]),
    );
  }
}
