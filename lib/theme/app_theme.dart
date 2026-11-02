import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

class AppTheme {
  /// [googleFonts] is off in tests, which can't download the font.
  static ThemeData light({bool googleFonts = true}) =>
      _build(RigColors.light, Brightness.light, googleFonts);

  static ThemeData dark({bool googleFonts = true}) =>
      _build(RigColors.dark, Brightness.dark, googleFonts);

  static TextTheme _textTheme(RigColors c, bool googleFonts) {
    TextStyle style(
      double size,
      FontWeight weight, {
      Color? color,
      double spacing = 0,
      double height = 1.35,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? c.textPrimary,
      letterSpacing: spacing,
      height: height,
    );

    final theme = TextTheme(
      displaySmall: style(32, FontWeight.w800, spacing: -1, height: 1.12),
      headlineMedium: style(28, FontWeight.w800, spacing: -0.8, height: 1.15),
      headlineSmall: style(24, FontWeight.w700, spacing: -0.5, height: 1.2),
      titleLarge: style(20, FontWeight.w700, spacing: -0.3, height: 1.25),
      titleMedium: style(16, FontWeight.w600, spacing: -0.1),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(12.5, FontWeight.w400, color: c.textSecondary),
      labelLarge: style(14, FontWeight.w600),
      labelMedium: style(12.5, FontWeight.w600, color: c.textSecondary),
      labelSmall: style(11, FontWeight.w600, color: c.textSecondary),
    );
    return googleFonts
        ? GoogleFonts.interTextTheme(theme)
        : theme.apply(fontFamily: 'Roboto');
  }

  static ThemeData _build(
    RigColors c,
    Brightness brightness,
    bool googleFonts,
  ) {
    final text = _textTheme(c, googleFonts);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    const buttonSize = Size(64, 52);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Space.xl);
    final buttonText = text.labelLarge!.copyWith(fontSize: 15);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      disabledBackgroundColor: c.surfaceRaised,
      disabledForegroundColor: c.textSecondary,
      minimumSize: buttonSize,
      padding: buttonPadding,
      shape: buttonShape,
      textStyle: buttonText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.accentAlt,
        onSecondary: c.onAccent,
        error: c.error,
        onError: c.onAccent,
        surface: c.surface,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        outline: c.border,
        outlineVariant: c.border,
        surfaceContainerHighest: c.surfaceRaised,
      ),
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.screen,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceRaised,
          disabledForegroundColor: c.textSecondary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: c.border),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(48, 44),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
        labelStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(c.border),
        focusedBorder: inputBorder(c.accent, 1.6),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, 1.6),
        errorStyle: text.bodySmall!.copyWith(color: c.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent,
        disabledColor: c.surfaceRaised,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelStyle: text.labelLarge!.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: c.onAccent),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.onAccent
                : c.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.accent : c.surface,
          ),
          shape: WidgetStatePropertyAll(buttonShape),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onAccent
              : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.surfaceRaised,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.background),
        actionTextColor: c.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        circularTrackColor: c.surfaceRaised,
        linearTrackColor: c.surfaceRaised,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: c.textSecondary,
        collapsedIconColor: c.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
