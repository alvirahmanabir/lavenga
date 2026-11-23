import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/user.dart';
import 'admin_common.dart';

class AdminPeopleScreen extends ConsumerStatefulWidget {
  const AdminPeopleScreen({super.key});
  @override
  ConsumerState<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends ConsumerState<AdminPeopleScreen> {
  String _q = '';
  AccountStatus? _status;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('People'),
          actions: [
            IconButton(
              tooltip: 'Add manager',
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => context.push('/a/manager/new'),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Customers'), Tab(text: 'Managers')]),
        ),
        body: AdminBody(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.sm),
                child: SearchField(
                  hint: 'Search by name, email or phone',
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                child: TabBarView(children: [
                  _CustomerList(query: _q, status: _status, onStatus: (s) => setState(() => _status = s)),
                  _ManagerList(query: _q),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerList extends ConsumerWidget {
  const _CustomerList({required this.query, required this.status, required this.onStatus});
  final String query;
  final AccountStatus? status;
  final ValueChanged<AccountStatus?> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider((UserRole.customer, query)));
    return Column(
      children: [
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
                  selected: status == null,
                  onSelected: (_) => onStatus(null),
                ),
              ),
              for (final s in AccountStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(_statusLabel(s)),
                    selected: status == s,
                    onSelected: (_) => onStatus(status == s ? null : s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<List<AppUser>>(
            value: users,
            onRetry: () => ref.invalidate(usersProvider),
            data: (all) {
              final list = status == null ? all : all.where((u) => u.status == status).toList();
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No customers found',
                  message: 'Try a different search or status filter.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _PersonTile(
                  user: list[i],
                  onTap: () => context.push('/a/customer/${list[i].id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _statusLabel(AccountStatus s) => switch (s) {
      AccountStatus.active => 'Active',
      AccountStatus.suspended => 'Suspended',
      AccountStatus.blacklisted => 'Blacklisted',
      AccountStatus.deactivated => 'Deactivated',
    };

class _ManagerList extends ConsumerWidget {
  const _ManagerList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider((UserRole.manager, query)));
    final studios = ref.watch(studiosProvider).valueOrNull ?? const [];
    final names = {for (final s in studios) s.id: s.name};
    return AsyncBody<List<AppUser>>(
      value: users,
      onRetry: () => ref.invalidate(usersProvider),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.badge_outlined,
            title: 'No managers found',
            message: 'Add a manager and assign the studios they run.',
            actionLabel: 'Add manager',
            onAction: () => context.push('/a/manager/new'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final u = list[i];
            final assigned = [for (final id in u.manager?.studioIds ?? const <String>[]) names[id] ?? id];
            return _PersonTile(
              user: u,
              subtitle: assigned.isEmpty ? 'No studios assigned' : assigned.join(', '),
              onTap: () => context.push('/a/manager/${u.id}'),
            );
          },
        );
      },
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.user, required this.onTap, this.subtitle});
  final AppUser user;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: UserAvatar(name: user.fullName, url: user.customer?.avatarUrl, radius: 22),
        title: Text(user.fullName),
        subtitle: Text(subtitle ?? user.identity),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.status != AccountStatus.active) AccountStatusBadge(user.status),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class ManagerDetailScreen extends ConsumerStatefulWidget {
  const ManagerDetailScreen({super.key, required this.managerId});
  final String managerId;

  @override
  ConsumerState<ManagerDetailScreen> createState() => _ManagerDetailState();
}

class _ManagerDetailState extends ConsumerState<ManagerDetailScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final Set<String> _studios = {};
  final Set<StaffPermission> _perms = {};
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.managerId == 'new';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _load(AppUser u) {
    if (_loaded) return;
    _loaded = true;
    _name.text = u.fullName;
    _email.text = u.email ?? '';
    _phone.text = u.phone ?? '';
    _studios
      ..clear()
      ..addAll(u.manager?.studioIds ?? const []);
    _perms
      ..clear()
      ..addAll(u.manager?.permissions ?? const {});
  }

  Future<void> _save(AppUser? existing) async {
    if (!_form.currentState!.validate()) return;
    if (_email.text.trim().isEmpty && _phone.text.trim().isEmpty) {
      showAppSnack(context, 'Add an email or a phone number', error: true);
      return;
    }
    final actor = ref.read(currentUserProvider);
    final users = ref.read(userRepositoryProvider);
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final email = _email.text.trim().isEmpty ? null : _email.text.trim();
      final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
      final profile = ManagerProfile(studioIds: _studios.toList(), permissions: {..._perms});
      if (existing == null) {
        await users.saveUser(
          AppUser(
            id: 'new',
            role: UserRole.manager,
            fullName: _name.text.trim(),
            email: email,
            phone: phone,
            password: _password.text,
            createdAt: DateTime.now().toUtc(),
            manager: profile,
          ),
          actor: actor,
        );
      } else {
        await users.saveUser(
          existing.copyWith(fullName: _name.text.trim(), email: email, phone: phone),
          actor: actor,
        );
        await users.setManagerAccess(
          existing.id,
          studioIds: profile.studioIds,
          permissions: profile.permissions,
          actor: actor,
        );
      }
    }, success: existing == null ? 'Manager created' : 'Manager updated');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && existing == null) context.pop();
  }

  Future<void> _toggleStatus(AppUser u) async {
    final actor = ref.read(currentUserProvider);
    final repo = ref.read(userRepositoryProvider);
    if (u.status == AccountStatus.active) {
      final reason = await askReason(
        context,
        title: 'Suspend ${u.fullName}?',
        hint: 'Reason (kept in the audit log)',
        confirmLabel: 'Suspend',
      );
      if (reason == null || !mounted) return;
      await runGuarded(
        context,
        () => repo.setAccountStatus(u.id, AccountStatus.suspended, actor: actor, reason: reason),
        success: 'Manager suspended',
      );
    } else {
      final ok = await showConfirmDialog(
        context,
        title: 'Reactivate ${u.fullName}?',
        message: 'They will be able to sign in again.',
        confirmLabel: 'Reactivate',
      );
      if (!ok || !mounted) return;
      await runGuarded(
        context,
        () => repo.setAccountStatus(u.id, AccountStatus.active, actor: actor),
        success: 'Manager reactivated',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final studios = ref.watch(studiosProvider);
    if (_isNew) {
      _loaded = true;
      return _scaffold(null, studios);
    }
    final user = ref.watch(userByIdProvider(widget.managerId));
    return user.when(
      data: (u) {
        _load(u);
        return _scaffold(u, studios);
      },
      loading: () => Scaffold(appBar: AppBar(title: const Text('Manager')), body: const ListSkeleton()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Manager')),
        body: AsyncBody<AppUser>(value: AsyncError(e, StackTrace.empty), data: (_) => const SizedBox()),
      ),
    );
  }

  Widget _scaffold(AppUser? u, AsyncValue studiosAsync) {
    final text = Theme.of(context).textTheme;
    final studioList = ref.watch(studiosProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(u == null ? 'New manager' : u.fullName)),
      body: AdminBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              if (u != null) ...[
                Row(children: [
                  UserAvatar(name: u.fullName, radius: 28),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.identity, style: text.bodyMedium),
                      const SizedBox(height: 4),
                      AccountStatusBadge(u.status),
                    ]),
                  ),
                ]),
                if (u.lastLoginAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: InfoRow(Icons.login, 'Last sign-in ${fmtDateTime(u.lastLoginAt!)}'),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                label: 'Full name',
                controller: _name,
                validator: Validators.fullName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.email(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.phone(v),
              ),
              if (u == null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Temporary password',
                  controller: _password,
                  obscure: true,
                  helper: 'Leave empty to use the demo password.',
                ),
              ],
              const SectionHeader('Studios they manage',
                  padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm)),
              Text('A manager only ever sees bookings, customers and payments of these studios.',
                  style: text.bodySmall),
              for (final s in studioList)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _studios.contains(s.id),
                  title: Text(s.name),
                  subtitle: Text(s.location),
                  onChanged: (v) => setState(() => v == true ? _studios.add(s.id) : _studios.remove(s.id)),
                ),
              const SectionHeader('Permissions',
                  padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm)),
              for (final p in StaffPermission.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _perms.contains(p),
                  title: Text(p.label),
                  onChanged: (v) => setState(() => v ? _perms.add(p) : _perms.remove(p)),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: u == null ? 'Create manager' : 'Save changes',
                loading: _saving,
                onPressed: () => _save(u),
              ),
              if (u != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: u.status == AccountStatus.active ? 'Suspend manager' : 'Reactivate manager',
                  kind: AppButtonKind.secondary,
                  onPressed: () => _toggleStatus(u),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
