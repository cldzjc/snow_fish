import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 全站主题：只暴露两套（亮/暗），由系统设置决定。
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.paper,
      secondary: c.ink,
      onSecondary: c.paper,
      error: c.danger,
      onError: c.paper,
      surface: c.paper,
      onSurface: c.ink,
      surfaceContainerHighest: c.soft,
      outline: c.line,
      outlineVariant: c.line,
    );

    final textTheme = TextTheme(
      displayLarge: AppText.display.copyWith(color: c.ink),
      displayMedium: AppText.display.copyWith(color: c.ink),
      titleLarge: AppText.pageTitle.copyWith(color: c.ink),
      titleMedium: AppText.title.copyWith(color: c.ink),
      bodyLarge: AppText.body.copyWith(color: c.ink),
      bodyMedium: AppText.body.copyWith(color: c.ink),
      bodySmall: AppText.meta.copyWith(color: c.muted),
      labelLarge: AppText.button.copyWith(color: c.ink),
      labelMedium: AppText.label.copyWith(color: c.muted),
      labelSmall: AppText.caption.copyWith(color: c.muted),
    );

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: c.ink,
        titleTextStyle: AppText.pageTitle.copyWith(color: c.ink),
        iconTheme: IconThemeData(color: c.ink, size: 22),
        toolbarHeight: AppSize.appBar,
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.ink, 1.4),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.4),
        labelStyle: AppText.label.copyWith(color: c.muted),
        floatingLabelStyle: AppText.label.copyWith(color: c.ink),
        hintStyle: AppText.body.copyWith(color: c.muted),
        errorStyle: AppText.caption.copyWith(color: c.danger),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: AppText.bodySmall.copyWith(color: c.paper),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpace.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        actionTextColor: c.paper,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppText.title.copyWith(color: c.ink),
        contentTextStyle: AppText.bodySmall.copyWith(color: c.ink),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xs,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(0, AppSize.tap),
          textStyle: AppText.button,
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
