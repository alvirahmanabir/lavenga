import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/enums.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Support tickets in the signed-in staff member's scope.
class StaffSupportScreen extends ConsumerStatefulWidget {
  const StaffSupportScreen({super.key});

  @override
  ConsumerState<StaffSupportScreen> createState() => _StaffSupportState();
}

class _StaffSupportState extends ConsumerState<StaffSupportScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    final allowed = PermissionPolicy.can(user, StaffPermission.handleSupport);
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: !allowed
          ? const NoAccess(what: 'support tickets')
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
                child: AsyncBody<List<SupportTicket>>(
                  value: ref.watch(staffTicketsProvider),
                  onRetry: () => ref.invalidate(staffTicketsProvider),
                  data: (all) {
                    final list = [
                      for (final t in all)
                        if (!_openOnly ||
                            (t.status != TicketStatus.resolved && t.status != TicketStatus.closed))
                          t
                    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.support_agent,
                        title: 'No tickets',
                        message: 'Customer support requests will appear here.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final t = list[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${t.reference} · ${t.customerName}\n${t.category} · ${fmtDate(t.updatedAt)}',
                                style: text.bodySmall),
                            isThreeLine: true,
                            trailing: TicketStatusBadge(t.status),
                            onTap: () => context.push('$p/support/${t.id}'),
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

/// Conversation with a customer. Staff can reply, escalate (managers) and
/// resolve or close.
class StaffTicketScreen extends ConsumerStatefulWidget {
  const StaffTicketScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<StaffTicketScreen> createState() => _StaffTicketState();
}

class _StaffTicketState extends ConsumerState<StaffTicketScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    final actor = ref.read(currentUserProvider);
    setState(() => _sending = true);
    final ok = await runGuarded(
      context,
      () => ref.read(supportRepositoryProvider).reply(widget.ticketId, body, actor: actor),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _reply.clear();
  }

  Future<void> _status(TicketStatus s, String done) async {
    final actor = ref.read(currentUserProvider);
    await runGuarded(
      context,
      () => ref.read(supportRepositoryProvider).setStatus(widget.ticketId, s, actor: actor),
      success: done,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final text = Theme.of(context).textTheme;
    if (!PermissionPolicy.can(user, StaffPermission.handleSupport)) {
      return Scaffold(appBar: AppBar(), body: const NoAccess(what: 'support tickets'));
    }
    final ticket = ref.watch(ticketProvider(widget.ticketId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        actions: [
          ticket.maybeWhen(
            data: (t) {
              final closed =
                  t.status == TicketStatus.resolved || t.status == TicketStatus.closed;
              return PopupMenuButton<String>(
                tooltip: 'Ticket actions',
                onSelected: (v) {
                  switch (v) {
                    case 'escalate':
                      _status(TicketStatus.escalated, 'Escalated to administrator');
                    case 'resolve':
                      _status(TicketStatus.resolved, 'Marked resolved');
                    case 'reopen':
                      _status(TicketStatus.awaitingCustomer, 'Reopened');
                    case 'booking':
                      context.push('$p/booking/${t.bookingId}');
                  }
                },
                itemBuilder: (_) => [
                  if (t.bookingId != null)
                    const PopupMenuItem(value: 'booking', child: Text('Open booking')),
                  if (user.isManager && !closed && t.status != TicketStatus.escalated)
                    const PopupMenuItem(value: 'escalate', child: Text('Escalate to administrator')),
                  if (!closed) const PopupMenuItem(value: 'resolve', child: Text('Mark resolved')),
                  if (closed) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AsyncBody<SupportTicket>(
        value: ticket,
        onRetry: () => ref.invalidate(ticketProvider(widget.ticketId)),
        data: (t) {
          final closed = t.status == TicketStatus.resolved || t.status == TicketStatus.closed;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.subject, style: text.titleMedium),
                    Text('${t.reference} · ${t.customerName} · ${t.category}',
                        style: text.bodySmall),
                  ]),
                ),
                TicketStatusBadge(t.status),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: t.messages.length,
                itemBuilder: (context, i) {
                  final m = t.messages[i];
                  final mine = m.senderRole != UserRole.customer;
                  final scheme = Theme.of(context).colorScheme;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                      decoration: BoxDecoration(
                        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.body),
                        const SizedBox(height: 4),
                        Text('${m.senderName} · ${fmtDateTime(m.at)}', style: text.bodySmall),
                      ]),
                    ),
                  );
                },
              ),
            ),
            if (closed)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: Text('This ticket is closed. Reopen it from the menu to reply.'),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: 'Write a reply'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      tooltip: 'Send reply',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
