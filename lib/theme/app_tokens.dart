import 'package:flutter/material.dart';

/// Spacing scale. Screens and cards use these instead of one-off values.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  /// Horizontal padding of every screen.
  static const double screen = 16;
}

abstract final class Radii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double xl = 34;
  static const double pill = 999;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 800);

  /// [duration], or zero when the device asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Bright blocks used in both themes. Ink text is readable on all of them.
abstract final class RigPalette {
  static const volt = Color(0xFFC8F135);
  static const tangerine = Color(0xFFFF9A5C);
  static const sun = Color(0xFFFFD84D);
  static const mint = Color(0xFF8FE3B8);
  static const sky = Color(0xFF9CD4FF);
  static const lilac = Color(0xFFCDBBFF);
  static const blush = Color(0xFFFFB9C6);
  static const ice = Color(0xFFB8F0EC);
  static const ink = Color(0xFF12140D);
}

/// SmartRig's colour tokens. Screens read these through `context.rig` instead
/// of naming colours, so every widget follows the selected theme.
class RigColors extends ThemeExtension<RigColors> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Emphasis on data, such as prices. Readable as text on surfaces.
  final Color accent;
  final Color accentAlt;
  final Color onAccent;

  /// The main action colour: primary buttons and active states.
  final Color volt;
  final Color onVolt;
  final Color success;
  final Color warning;
  final Color error;

  const RigColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentAlt,
    required this.onAccent,
    required this.volt,
    required this.onVolt,
    required this.success,
    required this.warning,
    required this.error,
  });

  static const light = RigColors(
    background: Color(0xFFEFEBE2),
    surface: Color(0xFFFFFEFA),
    surfaceRaised: Color(0xFFE5E0D4),
    border: Color(0xFFD9D3C5),
    textPrimary: RigPalette.ink,
    textSecondary: Color(0xFF5E5F54),
    accent: Color(0xFFB3420A),
    accentAlt: Color(0xFF6F3BD8),
    onAccent: Color(0xFFFFFFFF),
    volt: RigPalette.volt,
    onVolt: RigPalette.ink,
    success: Color(0xFF12763F),
    warning: Color(0xFF8F5400),
    error: Color(0xFFC92A3A),
  );

  static const dark = RigColors(
    background: Color(0xFF0A0B08),
    surface: Color(0xFF171914),
    surfaceRaised: Color(0xFF24271F),
    border: Color(0xFF32362C),
    textPrimary: Color(0xFFF6F8ED),
    textSecondary: Color(0xFFABB09F),
    accent: RigPalette.tangerine,
    accentAlt: Color(0xFFB79CFF),
    onAccent: RigPalette.ink,
    volt: RigPalette.volt,
    onVolt: RigPalette.ink,
    success: Color(0xFF5FDC8C),
    warning: Color(0xFFFFC24D),
    error: Color(0xFFFF7A7A),
  );

  /// A pale tint of [color], for pills and quiet backgrounds.
  Color soft(Color color) => color.withValues(alpha: 0.16);

  @override
  RigColors copyWith() => this;

  @override
  RigColors lerp(ThemeExtension<RigColors>? other, double t) {
    if (other is! RigColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return RigColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      accentAlt: mix(accentAlt, other.accentAlt),
      onAccent: mix(onAccent, other.onAccent),
      volt: mix(volt, other.volt),
      onVolt: mix(onVolt, other.onVolt),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
    );
  }
}

extension RigContext on BuildContext {
  RigColors get rig {
    final theme = Theme.of(this);
    return theme.extension<RigColors>() ??
        (theme.brightness == Brightness.dark
            ? RigColors.dark
            : RigColors.light);
  }

  TextTheme get text => Theme.of(this).textTheme;

  /// Bold figures with aligned digits, for scores, prices and FPS.
  TextStyle metric(double size, {Color? color}) => text.displaySmall!.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: size >= 24 ? -1 : -0.2,
    height: 1.12,
    color: color ?? rig.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
