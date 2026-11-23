import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/data_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/promo_social.dart';
import '../../../domain/models/user.dart';
import 'booking_providers.dart';
import 'common.dart';

// ---------------------------------------------------------------------------
// Profile hub
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = valueOf(ref.watch(customerSummaryProvider));
    final text = Theme.of(context).textTheme;

    Widget tile(IconData icon, String title, String route, {String? subtitle}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Row(
              children: [
                UserAvatar(name: user.fullName, url: user.customer?.avatarUrl, radius: 36),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: text.headlineSmall),
                      Text(user.identity, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (summary != null)
              SectionCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                title: 'Your activity',
                child: Column(
                  children: [
                    SummaryRow('Bookings', '${summary.bookings}'),
                    SummaryRow('Total spent', summary.lifetimeSpend.format()),
                    if (summary.refunded.isPositive)
                      SummaryRow('Refunded', summary.refunded.format()),
                    if (summary.outstanding.isPositive)
                      SummaryRow('Outstanding', summary.outstanding.format(),
                          valueColor: AppColors.terracotta),
                  ],
                ),
              ),
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  tile(Icons.edit_outlined, 'Edit profile', '/c/profile/edit'),
                  tile(Icons.lock_outline, 'Change password', '/c/profile/password'),
                  tile(Icons.notifications_outlined, 'Notification settings',
                      '/c/profile/notifications'),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  tile(Icons.currency_exchange, 'My refunds', '/c/refunds'),
                  tile(Icons.rate_review_outlined, 'My reviews', '/c/reviews'),
                  tile(Icons.local_offer_outlined, 'Offers', '/c/offers'),
                  tile(Icons.support_agent, 'Support', '/c/support'),
                  tile(Icons.policy_outlined, 'Policies and terms', '/c/policies'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Sign out',
              kind: AppButtonKind.secondary,
              icon: Icons.logout,
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Sign out?',
                  message: 'You can sign back in at any time.',
                  confirmLabel: 'Sign out',
                );
                if (ok) await ref.read(sessionProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile
// ---------------------------------------------------------------------------

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _extra;
  late final TextEditingController _address;
  Gender? _gender;
  DateTime? _dob;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _name = TextEditingController(text: u.fullName);
    _extra = TextEditingController(text: u.customer?.extraContact ?? '');
    _address = TextEditingController(text: u.customer?.address ?? '');
    _gender = u.customer?.gender;
    _dob = u.customer?.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    _extra.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = ref.read(currentUserProvider);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(userRepositoryProvider).updateCustomerProfile(
            u.id,
            fullName: _name.text.trim(),
            extraContact: _extra.text.trim(),
            address: _address.text.trim(),
            gender: _gender,
            dateOfBirth: _dob,
          ),
      success: 'Profile updated',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: CenteredBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              Center(child: UserAvatar(name: u.fullName, url: u.customer?.avatarUrl, radius: 40)),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(label: 'Full name', controller: _name, validator: Validators.fullName),
              const SizedBox(height: AppSpacing.lg),
              if (u.email != null) ...[
                AppTextField(
                  label: 'Email',
                  initialValue: u.email,
                  readOnly: true,
                  helper: 'Your registered email cannot be changed here.',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (u.phone != null) ...[
                AppTextField(
                  label: 'Phone',
                  initialValue: u.phone,
                  readOnly: true,
                  helper: 'Your registered phone cannot be changed here.',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                label: 'Additional contact (optional)',
                controller: _extra,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? null : Validators.phone(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(label: 'Address (optional)', controller: _address, maxLines: 2),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<Gender?>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender (optional)'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Prefer not to say')),
                  DropdownMenuItem(value: Gender.female, child: Text('Female')),
                  DropdownMenuItem(value: Gender.male, child: Text('Male')),
                  DropdownMenuItem(value: Gender.other, child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _pickDob,
                icon: const Icon(Icons.cake_outlined),
                label: Text(_dob == null ? 'Date of birth (optional)' : fmtDateLong(_dob!)),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Save changes', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change password
// ---------------------------------------------------------------------------

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = ref.read(currentUserProvider);
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref
          .read(userRepositoryProvider)
          .changePassword(u.id, current: _current.text, next: _next.text),
      success: 'Password changed',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: CenteredBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              AppTextField(
                label: 'Current password',
                controller: _current,
                obscure: true,
                validator: (v) => Validators.required(v, 'Current password'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'New password',
                controller: _next,
                obscure: true,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Confirm new password',
                controller: _confirm,
                obscure: true,
                validator: Validators.matches(() => _next.text),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Update password', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------

class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  static const _labels = {
    'bookings': ('Booking updates', 'Confirmations, rejections and reminders'),
    'payments': ('Payments and refunds', 'Receipts and refund progress'),
    'offers': ('Offers', 'Discounts and special deals'),
    'support': ('Support replies', 'Answers to your requests'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: CenteredBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            for (final e in _labels.entries)
              SwitchListTile(
                title: Text(e.value.$1),
                subtitle: Text(e.value.$2),
                value: user.notificationPrefs[e.key] ?? false,
                onChanged: (v) => runGuarded(
                  context,
                  () => ref
                      .read(userRepositoryProvider)
                      .setNotificationPrefs(user.id, {...user.notificationPrefs, e.key: v}),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Policies
// ---------------------------------------------------------------------------

class PoliciesScreen extends ConsumerWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Policies and terms')),
      body: AsyncBody<PlatformSettings>(
        value: settings,
        onRetry: () => ref.invalidate(settingsProvider),
        data: (s) => CenteredBody(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              _PolicyCard('Cancellation', s.cancellationPolicy),
              _PolicyCard('Advance payment', s.advancePolicy),
              _PolicyCard(
                'Refunds',
                s.refundPolicy,
                extra: [
                  for (final t in [...s.refundTiers]
                    ..sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore)))
                    SummaryRow(
                      t.hoursBefore > 0 ? '${t.hoursBefore}+ hours before' : 'Less than that',
                      '${(t.refundBp / 100).toStringAsFixed(t.refundBp % 100 == 0 ? 0 : 1)}%',
                    ),
                ],
              ),
              _PolicyCard('Terms of service', s.terms),
              _PolicyCard('Privacy', s.privacy),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard(this.title, this.body, {this.extra = const []});
  final String title;
  final String body;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...extra,
          ],
        ],
      ),
    );
  }
}
