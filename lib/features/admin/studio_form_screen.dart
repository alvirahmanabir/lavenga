import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/clock/clock.dart';
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
import '../../domain/models/catalogue.dart';
import 'admin_common.dart';

/// Create ('new') or edit a studio. Administrator only (enforced again in
/// the repository, never only in the UI).
class StudioFormScreen extends ConsumerStatefulWidget {
  const StudioFormScreen({super.key, required this.studioId});
  final String studioId;

  @override
  ConsumerState<StudioFormScreen> createState() => _StudioFormScreenState();
}

class _StudioFormScreenState extends ConsumerState<StudioFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController(text: 'Dhaka');
  final _image = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.studioId == 'new';

  @override
  void dispose() {
    for (final c in [_name, _description, _address, _area, _city, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Studio s) {
    if (_loaded) return;
    _loaded = true;
    _name.text = s.name;
    _description.text = s.description;
    _address.text = s.address;
    _area.text = s.area;
    _city.text = s.city;
    _image.text = s.imageUrl;
  }

  Future<void> _save(Studio? existing) async {
    if (!_form.currentState!.validate()) return;
    final actor = ref.read(currentUserProvider);
    final repo = ref.read(studioRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final image = _image.text.trim().isEmpty
        ? 'https://picsum.photos/seed/${_name.text.trim().hashCode.abs()}/900/600'
        : _image.text.trim();
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () async {
        final base = existing ??
            Studio(
              id: 'new',
              name: '',
              description: '',
              address: '',
              area: '',
              city: '',
              imageUrl: image,
              createdAt: now,
            );
        await repo.saveStudio(
          base.copyWith(
            name: _name.text.trim(),
            description: _description.text.trim(),
            address: _address.text.trim(),
            area: _area.text.trim(),
            city: _city.text.trim(),
            imageUrl: image,
          ),
          actor: actor,
        );
      },
      success: _isNew ? 'Studio created' : 'Studio saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  Future<void> _archive(Studio s) async {
    final yes = await showConfirmDialog(
      context,
      title: 'Archive ${s.name}?',
      message: 'Archived studios disappear from discovery. Existing bookings are kept.',
      confirmLabel: 'Archive',
      destructive: true,
    );
    if (!yes || !mounted) return;
    final actor = ref.read(currentUserProvider);
    final ok = await runGuarded(
      context,
      () => ref.read(studioRepositoryProvider).archiveStudio(s.id, actor: actor),
      success: 'Studio archived',
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isNew) return _scaffold(context, null);
    final value = ref.watch(studioProvider(widget.studioId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit studio')),
      body: AsyncBody<Studio>(
        value: value,
        onRetry: () => ref.invalidate(studioProvider(widget.studioId)),
        data: (s) {
          _load(s);
          return _formBody(context, s);
        },
      ),
    );
  }

  Widget _scaffold(BuildContext context, Studio? s) => Scaffold(
        appBar: AppBar(title: const Text('New studio')),
        body: _formBody(context, s),
      );

  Widget _formBody(BuildContext context, Studio? s) {
    return AdminBody(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            if (s != null && s.imageUrl.isNotEmpty) ...[
              AppImage(url: s.imageUrl, aspectRatio: 16 / 7, radius: AppRadii.card, semanticLabel: s.name),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: 'Studio name',
              controller: _name,
              validator: (v) => requiredField(v, 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Description',
              controller: _description,
              maxLines: 4,
              validator: (v) => requiredField(v, 'Description'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Street address',
              controller: _address,
              validator: (v) => requiredField(v, 'Address'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Area',
                    controller: _area,
                    validator: (v) => requiredField(v, 'Area'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'City',
                    controller: _city,
                    validator: (v) => requiredField(v, 'City'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Cover image URL',
              controller: _image,
              keyboardType: TextInputType.url,
              helper: 'Leave blank to use a placeholder. Uploads arrive with the backend.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isNew ? 'Create studio' : 'Save changes',
              loading: _saving,
              onPressed: () => _save(s),
            ),
            if (s != null && !s.archived) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Archive studio',
                kind: AppButtonKind.secondary,
                icon: Icons.archive_outlined,
                onPressed: () => _archive(s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
