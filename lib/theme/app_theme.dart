import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

class AppTheme {
  /// [googleFonts] is off in tests, which can't download the font.
  static ThemeData light({bool googleFonts = true}) {
    _googleFonts = googleFonts;
    return _build(RigColors.light, Brightness.light, googleFonts);
  }

  static ThemeData dark({bool googleFonts = true}) {
    _googleFonts = googleFonts;
    return _build(RigColors.dark, Brightness.dark, googleFonts);
  }

  static bool _googleFonts = true;
  static final _inkThemes = <bool, ThemeData>{};

  /// The dark theme, for panels that stay ink-coloured in either theme.
  static ThemeData get ink => _inkThemes[_googleFonts] ??= _build(
    RigColors.dark,
    Brightness.dark,
    _googleFonts,
  );

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
      displayLarge: style(52, FontWeight.w700, spacing: -2, height: 1),
      displayMedium: style(42, FontWeight.w700, spacing: -1.6, height: 1.02),
      displaySmall: style(34, FontWeight.w700, spacing: -1.2, height: 1.06),
      headlineMedium: style(30, FontWeight.w700, spacing: -1, height: 1.1),
      headlineSmall: style(26, FontWeight.w700, spacing: -0.8, height: 1.14),
      titleLarge: style(21, FontWeight.w700, spacing: -0.5, height: 1.2),
      titleMedium: style(17, FontWeight.w700, spacing: -0.3, height: 1.25),
      titleSmall: style(15, FontWeight.w600, spacing: -0.1, height: 1.3),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(12.5, FontWeight.w500, color: c.textSecondary),
      labelLarge: style(14, FontWeight.w700),
      labelMedium: style(12.5, FontWeight.w600, color: c.textSecondary),
      labelSmall: style(11, FontWeight.w600, color: c.textSecondary),
    );
    if (!googleFonts) return theme.apply(fontFamily: 'Roboto');

    // A characterful grotesque for headings and figures, Inter for reading.
    final display = GoogleFonts.spaceGroteskTextTheme(theme);
    final body = GoogleFonts.interTextTheme(theme);
    return display.copyWith(
      bodyLarge: body.bodyLarge,
      bodyMedium: body.bodyMedium,
      bodySmall: body.bodySmall,
      labelMedium: body.labelMedium,
      labelSmall: body.labelSmall,
    );
  }

  static ThemeData _build(
    RigColors c,
    Brightness brightness,
    bool googleFonts,
  ) {
    final text = _textTheme(c, googleFonts);
    const buttonShape = StadiumBorder();
    const buttonSize = Size(64, 56);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Space.xl);
    final buttonText = text.labelLarge!.copyWith(fontSize: 15.5);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: BorderSide(color: color, width: width),
        );

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: c.volt,
      foregroundColor: c.onVolt,
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
        primary: c.volt,
        onPrimary: c.onVolt,
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
        titleSpacing: Space.lg,
        titleTextStyle: text.headlineSmall,
      ),
      // A round back button, in every screen's app bar.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
          child: Icon(Icons.arrow_back, color: c.textPrimary, size: 20),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.volt,
          foregroundColor: c.onVolt,
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
          side: BorderSide(
            color: c.textPrimary.withValues(alpha: 0.28),
            width: 1.5,
          ),
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
          horizontal: Space.xl,
          vertical: Space.lg + 2,
        ),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(c.textPrimary, 2),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, 1.6),
        errorStyle: text.bodySmall!.copyWith(color: c.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.volt,
        disabledColor: c.surfaceRaised,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelStyle: text.labelLarge!.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: c.onVolt),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs + 2,
        ),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          side: const WidgetStatePropertyAll(BorderSide.none),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.onVolt
                : c.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.volt : c.surface,
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: c.textSecondary, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.volt
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onVolt),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onVolt
              : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.volt : c.surfaceRaised,
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
        strokeCap: StrokeCap.round,
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
