import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// Colour + icon + text, never colour alone. Booking, payment, refund and
/// hold badges are thin wrappers that map their enum to label/icon/tone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.of(tone);
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
