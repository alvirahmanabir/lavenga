import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/models/promo_social.dart';
import 'discovery_providers.dart';
import 'discovery_widgets.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteSpacesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: AsyncBody(
        value: favorites,
        onRetry: () => ref.invalidate(favoriteSpacesProvider),
        data: (spaces) {
          if (spaces.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: 'No favourites yet',
              message: 'Tap the heart on any space to save it here.',
              actionLabel: 'Explore spaces',
              onAction: () => context.go('/c/explore'),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.huge),
            child: SpaceGrid(spaces: spaces),
          );
        },
      ),
    );
  }
}

/// Shared by all roles; deep links use the role prefix.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String? _target(String prefix, AppNotification n) {
    final id = n.refId;
    if (id == null) return null;
    return switch (n.type) {
      'booking' || 'payment' => '$prefix/booking/$id',
      'refund' => '$prefix/refund/$id',
      'support' => '$prefix/support/$id',
      _ => null,
    };
  }

  IconData _icon(String type) => switch (type) {
        'booking' => Icons.event_available_outlined,
        'payment' => Icons.payments_outlined,
        'refund' => Icons.currency_exchange,
        'support' => Icons.support_agent,
        'offer' => Icons.local_offer_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final prefix = ref.watch(rolePrefixProvider);
    final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
    final now = ref.watch(clockProvider).now();
    final text = Theme.of(context).textTheme;
    final hasUnread = list.value?.any((n) => !n.read) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread && uid != null)
            TextButton(
              onPressed: () => runGuarded(
                context,
                () => ref.read(notificationRepositoryProvider).markAllRead(uid),
              ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncBody(
        value: list,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message: 'Booking, payment and support updates will appear here.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final target = _target(prefix, n);
              return Semantics(
                label: '${n.read ? '' : 'Unread. '}${n.title}. ${n.body}',
                child: ListTile(
                  minVerticalPadding: AppSpacing.md,
                  tileColor: n.read ? null : AppColors.terracotta.withValues(alpha: 0.06),
                  leading: Icon(_icon(n.type), color: AppColors.ink),
                  title: Text(n.title,
                      style: text.titleSmall?.copyWith(
                          fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Text('${n.body}\n${fmtAgo(n.createdAt, now)}'),
                  isThreeLine: true,
                  trailing: n.read
                      ? null
                      : const Icon(Icons.circle, size: 10, color: AppColors.terracotta),
                  onTap: () async {
                    if (!n.read) {
                      await ref.read(notificationRepositoryProvider).markRead(n.id);
                    }
                    if (target != null && context.mounted) context.push(target);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
