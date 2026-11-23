import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/enums.dart';
import '../../domain/models/promo_social.dart';
import 'admin_common.dart';

/// Append-only record of sensitive and administrative actions.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  bool _sensitive = false;
  bool _logins = false;
  UserRole? _role;

  @override
  Widget build(BuildContext context) {
    final key = (_sensitive, _role, _logins);
    final value = ref.watch(auditProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: AdminBody(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
                children: [
                  _chip('Sensitive only', _sensitive, (v) => setState(() => _sensitive = v)),
                  _chip('Sign-ins', _logins, (v) => setState(() => _logins = v)),
                  for (final r in [UserRole.customer, UserRole.manager, UserRole.admin])
                    _chip(r.label, _role == r, (v) => setState(() => _role = v ? r : null)),
                ],
              ),
            ),
            Expanded(
              child: AsyncBody<List<AuditLog>>(
                value: value,
                onRetry: () => ref.invalidate(auditProvider(key)),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'Nothing recorded',
                      message: 'No audit entries match these filters.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          l.sensitive ? Icons.shield_outlined : Icons.history,
                          color: l.sensitive ? AppColors.terracotta : AppColors.mutedText,
                          semanticLabel: l.sensitive ? 'Sensitive' : 'Routine',
                        ),
                        title: Text('${l.action} · ${l.target}'),
                        subtitle: Text(
                          '${l.actorName} (${l.actorRole.label}) · ${fmtDateTime(l.at)}'
                          '${l.detail == null ? '' : '\n${l.detail}'}',
                        ),
                        isThreeLine: l.detail != null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: FilterChip(label: Text(label), selected: selected, onSelected: onSelected),
      );
}
