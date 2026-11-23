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
import '../../data/mock/seed_data.dart';
import 'auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fill(String email) {
    setState(() {
      _id.text = email;
      _password.text = demoPassword;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      final user =
          await ref.read(sessionProvider.notifier).signIn(_id.text.trim(), _password.text);
      if (AuthConfig.requireEmailVerification && !user.verified) {
        router.push('/auth/otp?uid=${user.id}&mode=verify');
      }
      // Verified users: the session change makes the router redirect home.
    } catch (e) {
      if (mounted) showAppSnack(context, toFailure(e).userMessage, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      showBack: false,
      title: 'Welcome back',
      subtitle: 'Sign in with your email or phone number.',
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
                textInputAction: TextInputAction.next,
                validator: Validators.emailOrPhone,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscure: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.required(v, 'Password'),
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/auth/forgot'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(label: 'Sign in', loading: _busy, onPressed: _submit),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Create an account',
                kind: AppButtonKind.secondary,
                onPressed: () => context.push('/auth/register'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Demo accounts', style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Tap to fill the form. Password: $demoPassword', style: text.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: const Text('Customer'),
              onPressed: () => _fill(demoCustomerEmail),
            ),
            ActionChip(
              avatar: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Manager'),
              onPressed: () => _fill(demoManagerEmail),
            ),
            ActionChip(
              avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('Administrator'),
              onPressed: () => _fill(demoAdminEmail),
            ),
          ],
        ),
      ],
    );
  }
}
