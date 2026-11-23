import 'package:material_ui/material_ui.dart';

import '../errors/app_failure.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// "Never leave users with blank screens": every list uses one of these.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                kind: AppButtonKind.secondary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: failure.userMessage,
      actionLabel: failure.retryable && onRetry != null ? 'Try again' : null,
      onAction: onRetry,
    );
  }
}

/// Pulsing placeholder block for loading skeletons.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadii.field,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = reduceMotion ? 0.5 : _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(AppColors.line, const Color(0xFFF1ECE3), t),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          );
        },
      ),
    );
  }
}
