import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/account_repositories.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Customer directory. Requires the "view customers" permission.
class StaffCustomersScreen extends ConsumerStatefulWidget {
  const StaffCustomersScreen({super.key, this.embedded = true});
  final bool embedded;

  @override
  ConsumerState<StaffCustomersScreen> createState() => _StaffCustomersState();
}

class _StaffCustomersState extends ConsumerState<StaffCustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    final allowed = PermissionPolicy.can(user, StaffPermission.viewCustomers);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Customers'),
      ),
      body: !allowed
          ? const NoAccess(what: 'customer records')
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
                child: SearchField(
                  hint: 'Name, email or phone',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: AsyncBody<List<AppUser>>(
                  value: ref.watch(customerListProvider(_query)),
                  onRetry: () => ref.invalidate(customerListProvider(_query)),
                  data: (list) {
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers found',
                        message: 'Try a different name, email or phone number.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: UserAvatar(
                                name: c.fullName, url: c.customer?.avatarUrl, radius: 22),
                            title: Text(c.fullName),
                            subtitle: Text(c.identity, style: text.bodySmall),
                            trailing: c.status == AccountStatus.active
                                ? const Icon(Icons.chevron_right)
                                : AccountStatusBadge(c.status),
                            onTap: () => context.push('$p/customer/${c.id}'),
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

/// One customer: contact, lifetime figures and booking history. Only an
/// administrator may blacklist or change the customer discount.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  Future<void> _blacklist(BuildContext context, WidgetRef ref, AppUser c) async {
    final actor = ref.read(currentUserProvider);
    final restricted = c.status != AccountStatus.active;
    if (restricted) {
      final ok = await showConfirmDialog(
        context,
        title: 'Restore account?',
        message: '${c.fullName} will be able to sign in and book again.',
      );
      if (!ok || !context.mounted) return;
      await runGuarded(
        context,
        () => ref.read(userRepositoryProvider).setAccountStatus(c.id, AccountStatus.active,
            actor: actor),
        success: 'Account restored',
      );
      return;
    }
    final reason = await askReason(context,
        title: 'Blacklist customer', hint: 'Reason (kept in the audit log)');
    if (reason == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(userRepositoryProvider).setAccountStatus(c.id, AccountStatus.blacklisted,
          actor: actor, reason: reason),
      success: 'Customer blacklisted',
    );
  }

  Future<void> _discount(BuildContext context, WidgetRef ref, AppUser c) async {
    final controller = TextEditingController(
        text: ((c.customer?.discountBp ?? 0) / 100).toString());
    final value = await showAppSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Customer discount %'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save discount'),
          ),
          const SizedBox(height: AppSpacing.md),
        ]),
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    final pct = double.tryParse(value);
    if (pct == null || pct < 0 || pct > 100) {
      showAppSnack(context, 'Enter a percentage from 0 to 100', error: true);
      return;
    }
    final actor = ref.read(currentUserProvider);
    await runGuarded(
      context,
      () => ref
          .read(userRepositoryProvider)
          .setCustomerDiscount(c.id, (pct * 100).round(), actor: actor),
      success: 'Discount updated',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    if (!PermissionPolicy.can(user, StaffPermission.viewCustomers)) {
      return Scaffold(appBar: AppBar(), body: const NoAccess(what: 'customer records'));
    }
    final customer = ref.watch(customerUserProvider(customerId));
    final summary = ref.watch(customerSummaryProvider(customerId));
    final bookings = ref.watch(customerBookingsProvider(customerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: AsyncBody<AppUser>(
        value: customer,
        onRetry: () => ref.invalidate(customerUserProvider(customerId)),
        data: (c) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Row(children: [
                UserAvatar(name: c.fullName, url: c.customer?.avatarUrl, radius: 30),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.fullName, style: text.headlineSmall),
                    const SizedBox(height: 4),
                    AccountStatusBadge(c.status),
                  ]),
                ),
              ]),
            ),
            SectionCard(
              title: 'Contact',
              child: Column(children: [
                if (c.email != null) InfoRow(Icons.mail_outline, c.email!),
                if (c.phone != null) InfoRow(Icons.phone_outlined, c.phone!),
                if (c.customer?.extraContact != null)
                  InfoRow(Icons.phone_forwarded_outlined, c.customer!.extraContact!),
                if (c.customer?.address != null)
                  InfoRow(Icons.location_on_outlined, c.customer!.address!),
                InfoRow(Icons.event_outlined, 'Joined ${fmtDate(c.createdAt)}'),
              ]),
            ),
            if ((c.customer?.blacklistReason ?? '').isNotEmpty)
              SectionCard(
                title: 'Restriction reason',
                child: Text(c.customer!.blacklistReason!),
              ),
            SectionCard(
              title: 'Customer discount',
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${((c.customer?.discountBp ?? 0) / 100).toStringAsFixed(((c.customer?.discountBp ?? 0) % 100) == 0 ? 0 : 2)}% on every booking',
                  ),
                ),
                if (user.isAdmin)
                  TextButton(
                    onPressed: () => _discount(context, ref, c),
                    child: const Text('Change'),
                  ),
              ]),
            ),
            summary.maybeWhen(
              data: (CustomerSummary s) => SectionCard(
                title: 'Summary',
                child: Column(children: [
                  SummaryRow('Bookings', '${s.bookings}'),
                  SummaryRow('Net paid (after refunds)', s.lifetimeSpend.format()),
                  SummaryRow('Refunded', s.refunded.format()),
                  SummaryRow('Outstanding', s.outstanding.format()),
                  SummaryRow('Reviews', '${s.reviews}'),
                  SummaryRow('Support tickets', '${s.tickets}'),
                ]),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            if (user.isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: OutlinedButton.icon(
                  onPressed: () => _blacklist(context, ref, c),
                  icon: Icon(c.status == AccountStatus.active
                      ? Icons.block
                      : Icons.restore_outlined),
                  label: Text(c.status == AccountStatus.active
                      ? 'Blacklist customer'
                      : 'Restore account'),
                ),
              ),
            const SectionHeader('Booking history'),
            bookings.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: Text('Could not load bookings.'),
              ),
              data: (List<Booking> list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.gutter),
                      child: Text('No bookings in your scope.'),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                      child: Column(children: [
                        for (final b in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: StaffBookingCard(
                              booking: b,
                              onTap: () => context.push('$p/booking/${b.id}'),
                            ),
                          ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
