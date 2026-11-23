import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/auth_config.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback.dart';
import 'auth_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if ((v ?? '').trim().isEmpty && _phone.text.trim().isNotEmpty) return null;
    return Validators.email(v);
  }

  String? _phoneValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return null; // email alone is enough
    return Validators.phone(v);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      showAppSnack(context, 'Please accept the terms and privacy policy', error: true);
      return;
    }
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      final user = await ref.read(sessionProvider.notifier).register(
            fullName: _name.text.trim(),
            password: _password.text,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (AuthConfig.requireEmailVerification && !user.verified) {
        router.go('/auth/otp?uid=${user.id}&mode=register');
      } else {
        // No verification step: sign in right away; the router redirects home.
        await ref.read(sessionProvider.notifier).signIn(
              user.email ?? user.phone ?? '',
              _password.text,
            );
      }
    } catch (e) {
      if (mounted) showAppSnack(context, toFailure(e).userMessage, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Use an email, a phone number, or both.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Full name',
                controller: _name,
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                validator: Validators.fullName,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Email',
                controller: _email,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _emailValidator,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Phone',
                controller: _phone,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                hint: '01712345678',
                validator: _phoneValidator,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscure: true,
                prefixIcon: Icons.lock_outline,
                helper: 'At least 8 characters with letters and numbers',
                textInputAction: TextInputAction.next,
                validator: Validators.password,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Confirm password',
                controller: _confirm,
                obscure: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                validator: Validators.matches(() => _password.text),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
                title: Text('I agree to the terms and privacy policy',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Create account', loading: _busy, onPressed: _submit),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('I already have an account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
