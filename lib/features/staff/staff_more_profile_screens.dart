import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/services/policies.dart';

/// Overflow tab: everything that is not a main tab, limited to what the
/// signed-in role is permitted to open.
class StaffMoreScreen extends ConsumerWidget {
  const StaffMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    bool can(StaffPermission x) => PermissionPolicy.can(user, x);

    Widget tile(IconData icon, String title, String path, {String? subtitle}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: UserAvatar(name: user.fullName, radius: 22),
            title: Text(user.fullName),
            subtitle: Text('${user.role.label} · ${user.identity}'),
            onTap: () => context.push('$p/profile'),
          ),
          const Divider(),
          if (can(StaffPermission.handleRefunds))
            tile(Icons.assignment_return_outlined, 'Refund requests', '$p/refunds'),
          if (can(StaffPermission.handleSupport))
            tile(Icons.support_agent, 'Support tickets', '$p/support'),
          if (can(StaffPermission.viewReports))
            tile(Icons.bar_chart, 'Reports', '$p/reports'),
          tile(Icons.notifications_none, 'Notifications', '$p/notifications'),
          if (user.isAdmin) ...[
            const SectionHeader('Administration'),
            tile(Icons.payments_outlined, 'Payments', '/a/payments'),
            tile(Icons.local_offer_outlined, 'Promotions', '/a/promotions'),
            tile(Icons.tune, 'Platform settings', '/a/settings'),
            tile(Icons.policy_outlined, 'Policies', '/a/settings/policies'),
            tile(Icons.view_carousel_outlined, 'Home banners', '/a/settings/banners'),
            tile(Icons.history, 'Audit log', '/a/audit'),
          ],
          const Divider(),
          tile(Icons.person_outline, 'My profile', '$p/profile'),
        ],
      ),
    );
  }
}

/// Staff profile. Role, studios and permissions are read-only here: only an
/// administrator can change them.
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;
    final manager = user.manager;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
        children: [
          Center(child: UserAvatar(name: user.fullName, radius: 36)),
          const SizedBox(height: AppSpacing.md),
          Center(child: Text(user.fullName, style: text.headlineSmall)),
          Center(child: Text(user.role.label, style: text.bodyMedium)),
          SectionCard(
            title: 'Account',
            child: Column(children: [
              if (user.email != null) InfoRow(Icons.mail_outline, user.email!),
              if (user.phone != null) InfoRow(Icons.phone_outlined, user.phone!),
              if (user.lastLoginAt != null)
                InfoRow(Icons.login, 'Last sign-in ${fmtDateTime(user.lastLoginAt!)}'),
            ]),
          ),
          if (manager != null)
            SectionCard(
              title: 'Access',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Studios: ${manager.studioIds.length} assigned', style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                  for (final perm in manager.permissions)
                    Chip(label: Text(perm.label), visualDensity: VisualDensity.compact),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Text('Only an administrator can change this.', style: text.bodySmall),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Sign out?',
                  message: 'You will need to sign in again to continue.',
                  confirmLabel: 'Sign out',
                );
                if (!ok) return;
                await ref.read(sessionProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
