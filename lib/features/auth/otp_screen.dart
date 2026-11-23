import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/di/providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback.dart';
import '../../data/mock/seed_data.dart';
import 'auth_shell.dart';

/// mode: 'register' | 'verify' (unverified sign-in) | 'reset' (password reset).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.userId, required this.mode});
  final String userId;
  final String mode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  int _cooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final code = _code.text.trim();
    if (widget.mode == 'reset') {
      // The code is checked together with the new password on the next step.
      context.pushReplacement(
          '/auth/reset?uid=${Uri.encodeQueryComponent(widget.userId)}&code=$code');
      return;
    }
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      await ref.read(sessionProvider.notifier).verifyOtp(widget.userId, code);
      if (widget.mode == 'register') router.go('/auth/complete-profile');
    } catch (e) {
      if (mounted) showAppSnack(context, toFailure(e).userMessage, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final ok = await runGuarded(
      context,
      () => ref.read(authRepositoryProvider).resendOtp(widget.userId),
      success: 'A new code was sent',
    );
    if (ok) setState(_startCooldown);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: 'Enter the code',
      subtitle: 'We sent a 6-digit code to verify it is you.',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Verification code',
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                prefixIcon: Icons.pin_outlined,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.otp,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.oneTimeCode],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: widget.mode == 'reset' ? 'Continue' : 'Verify',
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _cooldown > 0
                    ? Text('Resend code in ${_cooldown}s', style: text.bodySmall)
                    : TextButton(onPressed: _resend, child: const Text('Resend code')),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DemoNote('Demo build: no SMS or email is sent. Use code $demoOtp.'),
            ],
          ),
        ),
      ],
    );
  }
}
