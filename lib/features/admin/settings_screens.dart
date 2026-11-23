import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/models/promo_social.dart';
import 'admin_common.dart';

Future<bool> _save(BuildContext context, WidgetRef ref, PlatformSettings s, String ok) {
  final actor = ref.read(currentUserProvider);
  return runGuarded(
    context,
    () => ref.read(adminRepositoryProvider).saveSettings(s, actor: actor),
    success: ok,
  );
}

/// Settings hub: current values at a glance, links to the detail screens and
/// the notification templates.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AdminBody(
        child: AsyncBody<PlatformSettings>(
          value: settings,
          onRetry: () => ref.invalidate(settingsProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              SectionCard(
                title: 'Current rules',
                child: Column(children: [
                  SummaryRow('Advance payment', '${percentText(s.advanceBp)}%'),
                  SummaryRow('Hold time', '${s.holdMinutes} minutes'),
                  SummaryRow('VAT', '${percentText(s.vatBp)}%'),
                  SummaryRow('Refund tiers', '${s.refundTiers.length}'),
                  SummaryRow('Home banners', '${s.banners.length}'),
                ]),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Policies and payment rules'),
                subtitle: const Text('Advance, hold time, VAT, refund tiers, policy text'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/a/settings/policies'),
              ),
              ListTile(
                leading: const Icon(Icons.view_carousel_outlined),
                title: const Text('Home banners'),
                subtitle: const Text('Shown at the top of the customer home screen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/a/settings/banners'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit log'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/a/audit'),
              ),
              const SectionHeader('Notification templates'),
              for (final e in s.notificationTemplates.entries)
                ListTile(
                  title: Text(e.key.replaceAll('_', ' ')),
                  subtitle: Text(e.value),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editTemplate(context, ref, s, e.key, e.value),
                ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: Text('Placeholders: {ref}, {amount}, {status}.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTemplate(
      BuildContext context, WidgetRef ref, PlatformSettings s, String key, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showAppSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppTextField(label: 'Template', controller: ctrl, maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save template',
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          ),
          const SizedBox(height: AppSpacing.lg),
        ]),
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty || !context.mounted) return;
    final map = Map<String, String>.from(s.notificationTemplates)..[key] = result;
    await _save(context, ref, s.copyWith(notificationTemplates: map), 'Template saved');
  }
}

/// Advance percentage, hold time, VAT, refund tiers and policy texts.
class PolicySettingsScreen extends ConsumerStatefulWidget {
  const PolicySettingsScreen({super.key});

  @override
  ConsumerState<PolicySettingsScreen> createState() => _PolicySettingsState();
}

class _PolicySettingsState extends ConsumerState<PolicySettingsScreen> {
  final _form = GlobalKey<FormState>();
  PlatformSettings? _loaded;
  late TextEditingController _advance, _hold, _vat, _cancel, _refund, _advText, _terms, _privacy;
  List<_TierCtrl> _tiers = [];
  bool _saving = false;

  void _init(PlatformSettings s) {
    if (_loaded != null) return;
    _loaded = s;
    _advance = TextEditingController(text: percentText(s.advanceBp));
    _hold = TextEditingController(text: '${s.holdMinutes}');
    _vat = TextEditingController(text: percentText(s.vatBp));
    _cancel = TextEditingController(text: s.cancellationPolicy);
    _refund = TextEditingController(text: s.refundPolicy);
    _advText = TextEditingController(text: s.advancePolicy);
    _terms = TextEditingController(text: s.terms);
    _privacy = TextEditingController(text: s.privacy);
    _tiers = [
      for (final t in s.refundTiers)
        _TierCtrl(TextEditingController(text: '${t.hoursBefore}'),
            TextEditingController(text: percentText(t.refundBp))),
    ];
  }

  @override
  void dispose() {
    if (_loaded != null) {
      for (final c in [_advance, _hold, _vat, _cancel, _refund, _advText, _terms, _privacy]) {
        c.dispose();
      }
      for (final t in _tiers) {
        t.hours.dispose();
        t.percent.dispose();
      }
    }
    super.dispose();
  }

  String? _pct(String? v, {int max = 100}) {
    final bp = parsePercentBp(v);
    if (bp == null) return 'Enter a number';
    if (bp < 0 || bp > max * 100) return 'Between 0 and $max';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final tiers = [
      for (final t in _tiers)
        RefundTier(int.parse(t.hours.text.trim()), parsePercentBp(t.percent.text)!),
    ]..sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));
    // Refunds must never grow as the session gets closer.
    for (var i = 1; i < tiers.length; i++) {
      if (tiers[i].refundBp > tiers[i - 1].refundBp) {
        showAppSnack(context, 'A later cancellation cannot refund more than an earlier one.',
            error: true);
        return;
      }
    }
    final next = _loaded!.copyWith(
      advanceBp: parsePercentBp(_advance.text)!,
      holdMinutes: int.parse(_hold.text.trim()),
      vatBp: parsePercentBp(_vat.text)!,
      refundTiers: tiers,
      cancellationPolicy: _cancel.text.trim(),
      refundPolicy: _refund.text.trim(),
      advancePolicy: _advText.text.trim(),
      terms: _terms.text.trim(),
      privacy: _privacy.text.trim(),
    );
    setState(() => _saving = true);
    final ok = await _save(context, ref, next, 'Policies saved. New bookings use these rules.');
    if (mounted) {
      setState(() => _saving = false);
      if (ok) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Policies and payment rules')),
      body: AdminBody(
        child: AsyncBody<PlatformSettings>(
          value: settings,
          onRetry: () => ref.invalidate(settingsProvider),
          data: (s) {
            _init(s);
            return Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  Text('Existing bookings keep the rules they were priced with.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Advance payment (% of total)',
                    controller: _advance,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _pct(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Hold time (minutes)',
                    controller: _hold,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 1 || n > 120 ? '1 to 120 minutes' : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'VAT (%)',
                    controller: _vat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _pct(v, max: 30),
                  ),
                  SectionHeader('Refund tiers',
                      actionLabel: 'Add tier',
                      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
                      onAction: () => setState(() => _tiers.add(
                          _TierCtrl(TextEditingController(text: '0'), TextEditingController(text: '0'))))),
                  Text('Refund share when cancelling at least N hours before the session.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < _tiers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Hours before',
                            controller: _tiers[i].hours,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                int.tryParse((v ?? '').trim()) == null ? 'Whole hours' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Refund %',
                            controller: _tiers[i].percent,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => _pct(v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove tier',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _tiers.length <= 1
                              ? null
                              : () => setState(() {
                                    final t = _tiers.removeAt(i);
                                    t.hours.dispose();
                                    t.percent.dispose();
                                  }),
                        ),
                      ]),
                    ),
                  const SectionHeader('Policy text',
                      padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
                  for (final f in [
                    ('Cancellation policy', _cancel),
                    ('Refund policy', _refund),
                    ('Advance payment policy', _advText),
                    ('Terms of use', _terms),
                    ('Privacy policy', _privacy),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppTextField(
                        label: f.$1,
                        controller: f.$2,
                        maxLines: 4,
                        validator: (v) => requiredField(v, f.$1),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'Save changes', loading: _saving, onPressed: _saving ? null : _submit),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TierCtrl {
  _TierCtrl(this.hours, this.percent);
  final TextEditingController hours;
  final TextEditingController percent;
}

/// Home banner management: add, edit, hide and delete.
class BannersScreen extends ConsumerWidget {
  const BannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Home banners')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('New banner'),
      ),
      body: AdminBody(
        child: AsyncBody<PlatformSettings>(
          value: settings,
          onRetry: () => ref.invalidate(settingsProvider),
          data: (s) {
            if (s.banners.isEmpty) {
              return const EmptyState(
                icon: Icons.view_carousel_outlined,
                title: 'No banners yet',
                message: 'Add a banner to promote an offer on the customer home screen.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 96),
              children: [
                for (final b in s.banners)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AspectRatio(
                        aspectRatio: 16 / 6,
                        child: AppImage(url: b.imageUrl, semanticLabel: b.title),
                      ),
                      ListTile(
                        title: Text(b.title),
                        subtitle: Text(b.subtitle),
                        trailing: Switch(
                          value: b.active,
                          onChanged: (v) => _save(context, ref,
                              s.copyWith(banners: _replace(s, b.copyWith(active: v))),
                              v ? 'Banner shown' : 'Banner hidden'),
                        ),
                      ),
                      OverflowBar(children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                          onPressed: () => _edit(context, ref, b),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          onPressed: () async {
                            final yes = await showConfirmDialog(context,
                                title: 'Delete banner?',
                                message: 'This removes "${b.title}" from the home screen.',
                                confirmLabel: 'Delete',
                                destructive: true);
                            if (yes && context.mounted) {
                              await _save(
                                  context,
                                  ref,
                                  s.copyWith(
                                      banners: [for (final x in s.banners) if (x.id != b.id) x]),
                                  'Banner deleted');
                            }
                          },
                        ),
                      ]),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<HomeBanner> _replace(PlatformSettings s, HomeBanner b) =>
      [for (final x in s.banners) x.id == b.id ? b : x];

  Future<void> _edit(BuildContext context, WidgetRef ref, HomeBanner? existing) async {
    final s = await ref.read(settingsProvider.future);
    if (!context.mounted) return;
    final title = TextEditingController(text: existing?.title ?? '');
    final sub = TextEditingController(text: existing?.subtitle ?? '');
    final key = GlobalKey<FormState>();
    final ok = await showAppSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTextField(
                label: 'Title',
                controller: title,
                maxLength: 60,
                validator: (v) => requiredField(v, 'Title')),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                label: 'Subtitle',
                controller: sub,
                maxLength: 100,
                validator: (v) => requiredField(v, 'Subtitle')),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: existing == null ? 'Add banner' : 'Save banner',
              onPressed: () {
                if (key.currentState!.validate()) Navigator.of(ctx).pop(true);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ]),
        ),
      ),
    );
    final t = title.text.trim(), st = sub.text.trim();
    title.dispose();
    sub.dispose();
    if (ok != true || !context.mounted) return;
    final List<HomeBanner> banners;
    if (existing == null) {
      final id = 'banner_${DateTime.now().microsecondsSinceEpoch}';
      banners = [
        ...s.banners,
        HomeBanner(id: id, title: t, subtitle: st, imageUrl: 'https://picsum.photos/seed/$id/1200/450'),
      ];
    } else {
      banners = _replace(s, existing.copyWith(title: t, subtitle: st));
    }
    await _save(context, ref, s.copyWith(banners: banners), 'Banner saved');
  }
}
