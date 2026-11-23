import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback.dart';
import 'auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    String? uid;
    final ok = await runGuarded(context, () async {
      uid = await ref.read(authRepositoryProvider).requestPasswordReset(_id.text.trim());
    });
    if (mounted) setState(() => _busy = false);
    if (ok && uid != null) router.push('/auth/otp?uid=$uid&mode=reset');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'Enter your email or phone and we will send a verification code.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Email or phone',
                controller: _id,
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.emailOrPhone,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Send code', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.userId, required this.code});
  final String userId;
  final String code;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final ok = await runGuarded(
      context,
      () => ref.read(authRepositoryProvider).resetPassword(
            userId: widget.userId,
            code: widget.code,
            newPassword: _password.text,
          ),
      success: 'Password updated. Please sign in.',
    );
    if (mounted) setState(() => _busy = false);
    if (ok) router.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'New password',
                controller: _password,
                obscure: true,
                prefixIcon: Icons.lock_outline,
                helper: 'At least 8 characters with letters and numbers',
                textInputAction: TextInputAction.next,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Confirm new password',
                controller: _confirm,
                obscure: true,
                prefixIcon: Icons.lock_outline,
                validator: Validators.matches(() => _password.text),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Update password', loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ],
    );
  }
}
