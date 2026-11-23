import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/enums.dart';
import '../../domain/models/catalogue.dart';
import 'admin_common.dart';

class AdminCatalogueScreen extends ConsumerWidget {
  const AdminCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catalogue'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              onSelected: (v) => _add(context, ref, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'studio', child: Text('New studio')),
                PopupMenuItem(value: 'space', child: Text('New space')),
                PopupMenuItem(value: 'category', child: Text('New category')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Studios'), Tab(text: 'Spaces'), Tab(text: 'Categories')],
          ),
        ),
        body: const AdminBody(
          child: TabBarView(children: [_StudiosTab(), _SpacesTab(), _CategoriesTab()]),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String what) async {
    switch (what) {
      case 'studio':
        context.push('/a/studio/new');
      case 'category':
        await _editCategory(context, ref, null);
      case 'space':
        final studios = await ref.read(studioRepositoryProvider).listStudios();
        if (!context.mounted || studios.isEmpty) return;
        final chosen = await showAppSheet<String>(
          context,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Which studio?', style: Theme.of(ctx).textTheme.headlineSmall),
              ),
              for (final s in studios)
                ListTile(
                  title: Text(s.name),
                  subtitle: Text(s.location),
                  onTap: () => Navigator.of(ctx).pop(s.id),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
        if (chosen != null && context.mounted) {
          context.push('/a/space/new/edit?studio=$chosen');
        }
    }
  }
}

Future<void> _editCategory(BuildContext context, WidgetRef ref, SpaceCategory? existing) async {
  final name = TextEditingController(text: existing?.name ?? '');
  var icon = existing?.icon ?? categoryIconKeys.first;
  final formKey = GlobalKey<FormState>();
  final actor = ref.read(currentUserProvider);
  final repo = ref.read(spaceRepositoryProvider);
  await showAppSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New category' : 'Edit category',
                  style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Name',
                controller: name,
                validator: (v) => requiredField(v, 'Name'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Icon', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final k in categoryIconKeys)
                    ChoiceChip(
                      label: Icon(categoryIcon(k), size: 20),
                      tooltip: k,
                      selected: icon == k,
                      onSelected: (_) => setState(() => icon = k),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final cat = existing?.copyWith(name: name.text.trim(), icon: icon) ??
                      SpaceCategory(id: 'new', name: name.text.trim(), icon: icon);
                  final ok = await runGuarded(
                    ctx,
                    () => repo.saveCategory(cat, actor: actor),
                    success: 'Category saved',
                  );
                  if (ok && ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
}

class _StudiosTab extends ConsumerWidget {
  const _StudiosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studios = ref.watch(_allStudiosProvider);
    final spaces = ref.watch(allSpacesProvider).valueOrNull ?? const [];
    return AsyncBody<List<Studio>>(
      value: studios,
      onRetry: () => ref.invalidate(_allStudiosProvider),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.store_outlined,
            title: 'No studios yet',
            message: 'Create the first studio to start listing spaces.',
            actionLabel: 'New studio',
            onAction: () => context.push('/a/studio/new'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) {
            final s = list[i];
            final n = spaces.where((x) => x.studioId == s.id).length;
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                leading: SizedBox(
                  width: 64,
                  height: 64,
                  child: AppImage(url: s.imageUrl, radius: 10, semanticLabel: s.name),
                ),
                title: Text(s.name),
                subtitle: Text('${s.location}\n$n spaces${s.archived ? ' - Archived' : ''}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/a/studio/${s.id}'),
              ),
            );
          },
        );
      },
    );
  }
}

final _allStudiosProvider = FutureProvider.autoDispose<List<Studio>>((ref) {
  ref.watch(dbVersionProvider);
  return ref.watch(studioRepositoryProvider).listStudios(includeArchived: true);
});

class _SpacesTab extends ConsumerStatefulWidget {
  const _SpacesTab();
  @override
  ConsumerState<_SpacesTab> createState() => _SpacesTabState();
}

class _SpacesTabState extends ConsumerState<_SpacesTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(allSpacesProvider);
    final studios = ref.watch(_allStudiosProvider).valueOrNull ?? const <Studio>[];
    final names = {for (final s in studios) s.id: s.name};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.sm),
          child: SearchField(
            hint: 'Search spaces or codes',
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: AsyncBody<List<StudioSpace>>(
            value: spaces,
            onRetry: () => ref.invalidate(allSpacesProvider),
            data: (all) {
              final list = all
                  .where((s) =>
                      _q.isEmpty ||
                      s.name.toLowerCase().contains(_q) ||
                      s.code.toLowerCase().contains(_q))
                  .toList();
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No spaces found',
                  message: 'Try a different search, or add a space from the + menu.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) {
                  final s = list[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: AppImage(
                          url: s.images.isEmpty ? null : s.images.first,
                          radius: 10,
                          semanticLabel: s.name,
                        ),
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                          '${s.code} - ${names[s.studioId] ?? ''}\n${s.hourlyRate.format()} / hour - ${_spaceStatusLabel(s.status)}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => context.push('/a/space/${s.id}/edit?studio=${s.studioId}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _spaceStatusLabel(SpaceStatus s) => switch (s) {
      SpaceStatus.active => 'Active',
      SpaceStatus.inactive => 'Inactive',
      SpaceStatus.archived => 'Archived',
    };

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(allCategoriesProvider);
    final actor = ref.watch(currentUserProvider);
    return AsyncBody<List<SpaceCategory>>(
      value: cats,
      onRetry: () => ref.invalidate(allCategoriesProvider),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final c = list[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(categoryIcon(c.icon)),
              title: Text(c.name),
              subtitle: Text(c.active ? 'Visible to customers' : 'Hidden'),
              onTap: () => _editCategory(context, ref, c),
              trailing: Switch(
                value: c.active,
                onChanged: (v) async {
                  if (!v) {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Hide ${c.name}?',
                      message: 'Customers will no longer see this category. Existing spaces are kept.',
                      confirmLabel: 'Hide',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                  }
                  await runGuarded(
                    context,
                    () => ref
                        .read(spaceRepositoryProvider)
                        .saveCategory(SpaceCategory(id: c.id, name: c.name, icon: c.icon, active: v), actor: actor),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
