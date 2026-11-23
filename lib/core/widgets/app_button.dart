import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

enum AppButtonKind { primary, secondary, text }

/// One button for the whole app. While [loading] it ignores taps, which is
/// the duplicate-submit guard the SRS requires for checkout and payment.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler = loading ? null : onPressed;
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final size = const Size(AppBreakpoints.minTouchTarget, AppBreakpoints.minTouchTarget);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
    );

    final button = switch (kind) {
      AppButtonKind.primary => FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(minimumSize: size, shape: shape),
          child: child,
        ),
      AppButtonKind.secondary => OutlinedButton(
          onPressed: handler,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            side: const BorderSide(color: AppColors.ink),
          ),
          child: child,
        ),
      AppButtonKind.text => TextButton(
          onPressed: handler,
          style: TextButton.styleFrom(minimumSize: size, shape: shape),
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: handler != null,
      label: loading ? '$label, loading' : label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
