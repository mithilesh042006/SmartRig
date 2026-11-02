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
  static const double screen = 20;
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
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

/// SmartRig's colour tokens. Screens read these through `context.rig` instead
/// of naming colours, so every widget follows the selected theme.
class RigColors extends ThemeExtension<RigColors> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentAlt;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color error;

  /// The hero and authentication panels stay deep in both themes.
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;
  final Color onHeroMuted;
  final Color viewerBackground;

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
    required this.success,
    required this.warning,
    required this.error,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.onHeroMuted,
    required this.viewerBackground,
  });

  static const light = RigColors(
    background: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEDF1F7),
    border: Color(0xFFDDE3EC),
    textPrimary: Color(0xFF151923),
    textSecondary: Color(0xFF5F697B),
    accent: Color(0xFF4460F6),
    accentAlt: Color(0xFF7C4DEE),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF0B8457),
    warning: Color(0xFFAD5A00),
    error: Color(0xFFD12C3A),
    heroStart: Color(0xFF12162B),
    heroEnd: Color(0xFF2B2A78),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFC3C9E6),
    viewerBackground: Color(0xFFE7EBF3),
  );

  static const dark = RigColors(
    background: Color(0xFF0B0D12),
    surface: Color(0xFF141821),
    surfaceRaised: Color(0xFF1B2130),
    border: Color(0xFF2A3244),
    textPrimary: Color(0xFFF4F6FB),
    textSecondary: Color(0xFF9AA4B5),
    accent: Color(0xFF6D83FF),
    accentAlt: Color(0xFFA78BFA),
    onAccent: Color(0xFF080A12),
    success: Color(0xFF3DD68C),
    warning: Color(0xFFF5B544),
    error: Color(0xFFFF6B72),
    heroStart: Color(0xFF171C3A),
    heroEnd: Color(0xFF322B85),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFC3C9E6),
    viewerBackground: Color(0xFF10131B),
  );

  /// A pale tint of [color], for pills and icon backgrounds.
  Color soft(Color color) => color.withValues(alpha: 0.14);

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroStart, heroEnd],
  );

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
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      heroStart: mix(heroStart, other.heroStart),
      heroEnd: mix(heroEnd, other.heroEnd),
      onHero: mix(onHero, other.onHero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      viewerBackground: mix(viewerBackground, other.viewerBackground),
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
  TextStyle metric(double size, {Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: size >= 24 ? -0.8 : -0.2,
    height: 1.18,
    color: color ?? rig.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
