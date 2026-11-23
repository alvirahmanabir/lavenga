import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';

/// Common frame for auth screens: centred, width-limited, scrollable,
/// keyboard safe, with an optional back button and heading.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: showBack),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
              children: [
                Text(title, style: text.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle!, style: text.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.xl),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small notice used for the demo hints (OTP code, demo accounts).
class DemoNote extends StatelessWidget {
  const DemoNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.mutedText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
