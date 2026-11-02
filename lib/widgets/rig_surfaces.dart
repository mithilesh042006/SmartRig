import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

enum RigCardTone { normal, selected, warning, error }

/// The standard surface. With [onTap] it responds to presses.
class RigCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final RigCardTone tone;
  final bool raised;

  /// A solid fill, for colour-blocked cards. Text on it should be ink.
  final Color? color;

  const RigCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.tone = RigCardTone.normal,
    this.raised = false,
    this.color,
  });

  @override
  State<RigCard> createState() => _RigCardState();
}

class _RigCardState extends State<RigCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final borderColor = switch (widget.tone) {
      RigCardTone.normal => Colors.transparent,
      RigCardTone.selected => c.textPrimary,
      RigCardTone.warning => c.warning,
      RigCardTone.error => c.error,
    };

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: Motion.of(context, Motion.fast),
      child: Material(
        color: widget.color ?? (widget.raised ? c.surfaceRaised : c.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: widget.tone == RigCardTone.normal
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: widget.onTap == null
              ? null
              : (value) => setState(() => _pressed = value),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

/// A solid rounded tile holding an icon, used to anchor cards and list rows.
class RigIconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const RigIconBox({super.key, required this.icon, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final fill = color ?? context.rig.volt;
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : RigPalette.ink;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: onFill, size: size * 0.52),
    );
  }
}

/// A small rounded label for statuses and metadata.
class RigPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const RigPill({super.key, required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.rig.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md - 2,
        vertical: Space.xs + 1,
      ),
      decoration: BoxDecoration(
        color: context.rig.soft(tint),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: Space.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(
                color: tint,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.headlineSmall),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Keeps content at a readable width on tablets and desktop.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// SmartRig's mark: four part-coloured blocks on ink.
class RigMark extends StatelessWidget {
  final double size;

  const RigMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.09;
    final block = (size - gap * 3) / 2;

    Widget tile(Color color, {bool round = false}) => Container(
      width: block,
      height: block,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(block * (round ? 0.5 : 0.28)),
      ),
    );

    return Semantics(
      label: 'SmartRig',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(
          color: RigPalette.ink,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tile(RigPalette.volt),
                tile(RigPalette.tangerine, round: true),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tile(RigPalette.sun, round: true),
                tile(RigPalette.mint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Gives its content the dark tokens, for panels that stay ink in both themes.
class RigInk extends StatelessWidget {
  final Widget child;

  const RigInk({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return child;
    return Theme(data: AppTheme.ink, child: child);
  }
}

/// A dark card with the dark tokens applied to its content.
class RigInkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const RigInkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RigInk(
      child: RigCard(
        color: RigPalette.ink,
        padding: padding,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A short fade and rise as a section appears. Skipped with reduced motion.
class RigReveal extends StatelessWidget {
  final int order;
  final Widget child;

  const RigReveal({super.key, this.order = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(
      context,
      Duration(milliseconds: 320 + order * 70),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Sticky bottom area for a screen's main actions.
class RigActionBar extends StatelessWidget {
  final Widget child;

  const RigActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.md,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
