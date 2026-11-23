import 'package:material_ui/material_ui.dart';

/// Raw design tokens. Widgets should prefer Theme.of(context) and the
/// [LavengaStatusColors] extension; use these only inside the theme layer.
abstract final class AppColors {
  static const ink = Color(0xFF1C1B19);
  static const paper = Color(0xFFFAF7F2);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8E2D9);
  static const mutedText = Color(0xFF6B665E);
  static const terracotta = Color(0xFFB4552F);
  static const success = Color(0xFF2F7D4F);
  static const warning = Color(0xFF946815);
  static const error = Color(0xFFB3382C);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
  static const double gutter = 20;
}

abstract final class AppRadii {
  static const double field = 12;
  static const double card = 16;
  static const double pill = 999;
}

abstract final class AppBreakpoints {
  /// Width at which staff shells switch from a bottom bar to a rail.
  static const double wide = 840;
  static const double minTouchTarget = 48;
}

abstract final class AppFonts {
  /// Not bundled yet: Flutter falls back to the platform font until the
  /// font assets are added to pubspec (planned before release).
  static const display = 'Fraunces';
  static const body = 'Inter';
}

enum StatusTone { success, warning, error, info, neutral }

/// Semantic colors for status badges. Always paired with an icon and label.
@immutable
class LavengaStatusColors extends ThemeExtension<LavengaStatusColors> {
  const LavengaStatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color neutral;

  static const light = LavengaStatusColors(
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: Color(0xFF2A5F8F),
    neutral: AppColors.mutedText,
  );

  Color of(StatusTone tone) => switch (tone) {
        StatusTone.success => success,
        StatusTone.warning => warning,
        StatusTone.error => error,
        StatusTone.info => info,
        StatusTone.neutral => neutral,
      };

  @override
  LavengaStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? neutral,
  }) =>
      LavengaStatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        info: info ?? this.info,
        neutral: neutral ?? this.neutral,
      );

  @override
  LavengaStatusColors lerp(LavengaStatusColors? other, double t) {
    if (other == null) return this;
    return LavengaStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  LavengaStatusColors get statusColors =>
      Theme.of(this).extension<LavengaStatusColors>() ??
      LavengaStatusColors.light;
}
