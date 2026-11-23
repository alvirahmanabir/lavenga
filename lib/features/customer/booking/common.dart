import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/feedback.dart';

const double kContentMaxWidth = 720;

/// Centers content with a readable maximum width on tablets.
class CenteredBody extends StatelessWidget {
  const CenteredBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: child,
      ),
    );
  }
}

/// Bottom action bar that stays above the keyboard and system insets.
class StickyBar extends StatelessWidget {
  const StickyBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.md),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Value of an [AsyncValue] if present (works while refreshing), else null.
T? valueOf<T>(AsyncValue<T> a) => a.hasValue ? a.requireValue : null;

/// Runs [action] and returns its result, or null after showing a mapped
/// failure snackbar. Use when the caller needs the created object.
Future<T?> guardedValue<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
}) async {
  try {
    final result = await action();
    if (context.mounted && success != null) showAppSnack(context, success);
    return result;
  } catch (e) {
    if (context.mounted) showAppSnack(context, toFailure(e).userMessage, error: true);
    return null;
  }
}

/// Plain number for text fields ("1200" or "1200.50").
String moneyInput(Money m) {
  final whole = m.minor ~/ 100;
  final frac = m.minor % 100;
  return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
}

/// Single-choice tile (used instead of Radio widgets). Colour is never the
/// only signal: the selected tile also swaps its icon.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.ink : AppColors.mutedText,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline notice (info, warning or error) with icon and text.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.tone = StatusTone.info, this.icon});
  final String text;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.of(tone);
    final iconData = icon ??
        switch (tone) {
          StatusTone.success => Icons.check_circle_outline,
          StatusTone.warning => Icons.warning_amber_rounded,
          StatusTone.error => Icons.error_outline,
          _ => Icons.info_outline,
        };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Live countdown for a server-issued hold. When it reaches zero it bumps
/// the data version so the repository can release the slots and screens
/// reload the booking as expired.
class HoldCountdown extends ConsumerStatefulWidget {
  const HoldCountdown({super.key, required this.expiresAt});
  final DateTime expiresAt;

  @override
  ConsumerState<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends ConsumerState<HoldCountdown> {
  Timer? _timer;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final now = ref.read(clockProvider).now();
      if (!now.isBefore(widget.expiresAt) && !_notified) {
        _notified = true;
        ref.read(dbVersionProvider.notifier).bump();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider).now();
    final remaining = widget.expiresAt.difference(now);
    final expired = !remaining.isNegative ? false : true;
    final color = context.statusColors.of(expired ? StatusTone.error : StatusTone.warning);
    return Semantics(
      label: expired
          ? 'Reservation expired'
          : 'Slots held for ${fmtCountdown(remaining)} minutes',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Row(
          children: [
            Icon(expired ? Icons.timer_off : Icons.hourglass_top, color: color, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                expired
                    ? 'Reservation expired. The slots were released.'
                    : 'Slots held while you pay · ${fmtCountdown(remaining)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
