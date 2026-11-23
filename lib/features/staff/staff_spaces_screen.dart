import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/data_providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/enums.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';

/// Spaces the signed-in staff member may manage (manager: assigned studios).
class StaffSpacesScreen extends ConsumerStatefulWidget {
  const StaffSpacesScreen({super.key});

  @override
  ConsumerState<StaffSpacesScreen> createState() => _StaffSpacesState();
}

class _StaffSpacesState extends ConsumerState<StaffSpacesScreen> {
  String _query = '';

  Future<void> _create() async {
    final user = ref.read(currentUserProvider);
    final p = ref.read(rolePrefixProvider);
    final studios = await ref.read(studiosProvider.future);
    final mine = [for (final s in studios) if (PermissionPolicy.managesStudio(user, s.id)) s];
    if (!mounted) return;
    if (mine.isEmpty) return;
    var studioId = mine.first.id;
    if (mine.length > 1) {
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choose a studio'),
          children: [
            for (final s in mine)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(s.id),
                child: Text(s.name),
              ),
          ],
        ),
      );
      if (picked == null) return;
      studioId = picked;
    }
    if (!mounted) return;
    context.push('$p/space/new/edit?studio=$studioId');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final spaces = ref.watch(staffSpacesProvider);
    final canCreate = PermissionPolicy.can(user, StaffPermission.createSpaces);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Spaces')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('New space'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by name or code',
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: AsyncBody<List<StudioSpace>>(
            value: spaces,
            onRetry: () => ref.invalidate(staffSpacesProvider),
            data: (all) {
              final list = [
                for (final s in all)
                  if (_query.isEmpty ||
                      s.name.toLowerCase().contains(_query) ||
                      s.code.toLowerCase().contains(_query))
                    s
              ];
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'No spaces',
                  message: 'No spaces match, or none are assigned to you yet.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      onTap: () => context.push('$p/space/${s.id}/edit?studio=${s.studioId}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: AppImage(
                              url: s.images.isEmpty ? null : s.images.first,
                              radius: 12,
                              semanticLabel: s.name,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: text.titleMedium),
                                Text('${s.code} · ${s.hourlyRate.format()}/hr',
                                    style: text.bodySmall),
                                const SizedBox(height: 4),
                                Text(
                                  switch (s.status) {
                                    SpaceStatus.active => 'Active',
                                    SpaceStatus.inactive => 'Inactive (hidden from customers)',
                                    SpaceStatus.archived => 'Archived',
                                  },
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
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
