import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback.dart';
import '../../domain/enums.dart';
import 'auth_shell.dart';

/// Optional profile details right after verification. Everything is skippable.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _address = TextEditingController();
  final _extra = TextEditingController();
  Gender? _gender;
  DateTime? _dob;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _finish() {
    final user = ref.read(sessionProvider).user;
    context.go(user?.role.home ?? '/auth/login');
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final user = ref.read(sessionProvider).user;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(userRepositoryProvider).updateCustomerProfile(
            user.id,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            extraContact: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
            gender: _gender,
            dateOfBirth: _dob == null ? null : fromStudioLocal(_dob!.year, _dob!.month, _dob!.day),
          ),
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      showBack: false,
      title: 'Tell us a little more',
      subtitle: 'Optional. You can change these later in your profile.',
      children: [
        Text('Gender', style: text.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final g in Gender.values)
              ChoiceChip(
                label: Text(g.name[0].toUpperCase() + g.name.substring(1)),
                selected: _gender == g,
                onSelected: (s) => setState(() => _gender = s ? g : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Date of birth', style: text.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppBreakpoints.minTouchTarget),
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.cake_outlined, size: 18),
          label: Text(_dob == null ? 'Select date' : fmtDateLong(fromStudioLocal(_dob!.year, _dob!.month, _dob!.day))),
          onPressed: _pickDob,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Address',
          controller: _address,
          prefixIcon: Icons.home_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Additional contact number',
          controller: _extra,
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Save and continue', loading: _busy, onPressed: _save),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Skip for now', kind: AppButtonKind.text, onPressed: _finish),
      ],
    );
  }
}
