import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/promo_social.dart';
import 'booking_providers.dart';
import 'common.dart';

const _categories = [
  'Booking',
  'Payment',
  'Refund',
  'Studio or space',
  'Account',
  'Other',
];

// ---------------------------------------------------------------------------
// Inbox
// ---------------------------------------------------------------------------

class SupportInboxScreen extends ConsumerWidget {
  const SupportInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(myTicketsProvider);
    final now = ref.watch(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/c/support/new'),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: AsyncBody<List<SupportTicket>>(
        value: tickets,
        onRetry: () => ref.invalidate(myTicketsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.support_agent,
              title: 'No support requests',
              message: 'Need help with a booking or payment? Send us a message.',
              actionLabel: 'New request',
              onAction: () => context.push('/c/support/new'),
            );
          }
          final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return CenteredBody(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.gutter, AppSpacing.gutter, 96),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final t = sorted[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.push('/c/support/${t.id}'),
                    leading: t.unreadForCustomer
                        ? const Icon(Icons.mark_email_unread, semanticLabel: 'Unread reply')
                        : const Icon(Icons.mail_outline),
                    title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${t.reference} · ${fmtAgo(t.updatedAt, now)}'),
                    trailing: TicketStatusBadge(t.status),
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

// ---------------------------------------------------------------------------
// New request
// ---------------------------------------------------------------------------

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.bookingId});
  final String? bookingId;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = _categories.first;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    setState(() => _busy = true);
    final ticket = await guardedValue<SupportTicket>(
      context,
      () => ref.read(supportRepositoryProvider).create(
            customer: user,
            category: _category,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            bookingId: widget.bookingId,
          ),
      success: 'Request sent',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ticket != null) context.pushReplacement('/c/support/${ticket.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: CenteredBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              if (widget.bookingId != null) ...[
                const Notice(text: 'This request will be linked to your booking.'),
                const SizedBox(height: AppSpacing.lg),
              ],
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in _categories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Subject',
                controller: _subject,
                maxLength: 100,
                validator: (v) => Validators.minLength(v, 5, 'Subject'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'How can we help?',
                controller: _body,
                maxLines: 6,
                maxLength: 1000,
                validator: (v) => Validators.minLength(v, 10, 'Message'),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Send request', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

class TicketConversationScreen extends ConsumerStatefulWidget {
  const TicketConversationScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<TicketConversationScreen> createState() => _TicketConversationScreenState();
}

class _TicketConversationScreenState extends ConsumerState<TicketConversationScreen> {
  final _reply = TextEditingController();
  bool _busy = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    final user = ref.read(currentUserProvider);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(supportRepositoryProvider).reply(widget.ticketId, body, actor: user),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _reply.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider(widget.ticketId));
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;

    final t = valueOf(ticket);
    if (t != null && t.unreadForCustomer && !_markedRead) {
      _markedRead = true;
      Future(() => ref.read(supportRepositoryProvider).markRead(widget.ticketId));
    }
    final closed = t?.status == TicketStatus.closed;

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.reference ?? 'Request'),
        actions: [
          if (t?.bookingId != null)
            IconButton(
              tooltip: 'View booking',
              icon: const Icon(Icons.event_note),
              onPressed: () => context.push('/c/booking/${t!.bookingId}'),
            ),
        ],
      ),
      body: AsyncBody<SupportTicket>(
        value: ticket,
        onRetry: () => ref.invalidate(ticketProvider(widget.ticketId)),
        data: (t) => Column(
          children: [
            Expanded(
              child: CenteredBody(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(t.subject, style: text.titleLarge)),
                        TicketStatusBadge(t.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(t.category, style: text.bodySmall),
                    const SizedBox(height: AppSpacing.lg),
                    for (final m in t.messages) _Bubble(message: m, mine: m.senderId == user.id),
                  ],
                ),
              ),
            ),
            if (closed)
              const StickyBar(child: Notice(text: 'This request is closed. Open a new request if you need more help.'))
            else
              StickyBar(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(hintText: 'Write a reply'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      tooltip: 'Send reply',
                      onPressed: _busy ? null : _send,
                      icon: _busy
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: mine ? null : Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'You' : '${message.senderName} · ${message.senderRole.label}',
              style: text.labelSmall?.copyWith(color: mine ? scheme.onPrimary : AppColors.mutedText),
            ),
            const SizedBox(height: 2),
            Text(message.body, style: text.bodyMedium?.copyWith(color: mine ? scheme.onPrimary : null)),
            const SizedBox(height: 4),
            Text(
              fmtDateTime(message.at),
              style: text.labelSmall?.copyWith(color: mine ? scheme.onPrimary : AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
