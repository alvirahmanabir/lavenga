import 'package:material_ui/material_ui.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.paper,
      secondary: AppColors.terracotta,
      onSecondary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    final textTheme = _textTheme();

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      fontFamily: AppFonts.body,
      extensions: const [LavengaStatusColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.ink, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.ink.withValues(alpha: 0.08),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.ink,
        labelStyle: textTheme.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.paper),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
    );
  }

  static TextTheme _textTheme() {
    TextStyle display(double size, double height) => TextStyle(
          fontFamily: AppFonts.display,
          fontSize: size,
          height: height / size,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        );
    TextStyle body(double size, double height,
            {FontWeight weight = FontWeight.w400, Color? color}) =>
        TextStyle(
          fontFamily: AppFonts.body,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          color: color ?? AppColors.ink,
        );

    return TextTheme(
      displaySmall: display(32, 40),
      headlineMedium: display(24, 32),
      headlineSmall: display(20, 28),
      titleLarge: display(20, 28),
      titleMedium: body(16, 24, weight: FontWeight.w600),
      bodyLarge: body(16, 24),
      bodyMedium: body(14, 20),
      bodySmall: body(12, 16, color: AppColors.mutedText),
      labelLarge: body(14, 20, weight: FontWeight.w600),
      labelMedium: body(12, 16, weight: FontWeight.w600),
    );
  }
}
