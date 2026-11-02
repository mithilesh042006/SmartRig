import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

enum RigCardTone { normal, selected, warning, error }

/// The standard surface. With [onTap] it responds to presses.
class RigCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final RigCardTone tone;
  final bool raised;

  const RigCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.tone = RigCardTone.normal,
    this.raised = false,
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
      RigCardTone.normal => c.border,
      RigCardTone.selected => c.accent.withValues(alpha: 0.55),
      RigCardTone.warning => c.warning.withValues(alpha: 0.55),
      RigCardTone.error => c.error.withValues(alpha: 0.55),
    };

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: Motion.of(context, Motion.fast),
      child: Material(
        color: widget.raised ? c.surfaceRaised : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: borderColor),
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

/// A tinted square holding an icon, used to anchor cards and list rows.
class RigIconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const RigIconBox({super.key, required this.icon, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.rig.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.rig.soft(tint),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Icon(icon, color: tint, size: size * 0.52),
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
              style: context.text.labelSmall!.copyWith(color: tint),
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
              child: Text(title, style: context.text.titleLarge),
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

/// SmartRig's compact app mark.
class RigMark extends StatelessWidget {
  final double size;

  const RigMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Semantics(
      label: 'SmartRig',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [RigColors.light.accent, RigColors.light.accentAlt],
          ),
        ),
        child: Icon(Icons.memory, color: c.onHero, size: size * 0.6),
      ),
    );
  }
}

/// Faint motherboard-style traces, drawn behind hero panels.
class CircuitPattern extends StatelessWidget {
  final Color color;

  const CircuitPattern({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(painter: _CircuitPainter(color), size: Size.infinite),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  final Color color;

  _CircuitPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final pad = Paint()..color = color;

    // Traces run in from the right edge and step down at 45 degrees.
    void trace(double startY, double runX, double dropY, double endX) {
      final x0 = size.width;
      final x1 = size.width - runX;
      final y1 = startY + dropY;
      final x2 = x1 - dropY;
      final x3 = size.width - endX;
      canvas.drawPath(
        Path()
          ..moveTo(x0, startY)
          ..lineTo(x1, startY)
          ..lineTo(x2, y1)
          ..lineTo(x3, y1),
        line,
      );
      canvas.drawCircle(Offset(x3, y1), 3, pad);
    }

    final h = size.height;
    trace(h * 0.08, 46, 22, 150);
    trace(h * 0.2, 28, 30, 190);
    trace(h * 0.34, 60, 18, 128);
    trace(h * 0.5, 22, 34, 168);
    trace(h * 0.68, 54, 20, 112);
    trace(h * 0.82, 30, 16, 92);
  }

  @override
  bool shouldRepaint(_CircuitPainter oldDelegate) => oldDelegate.color != color;
}

/// Sticky bottom area for a screen's main actions.
class RigActionBar extends StatelessWidget {
  final Widget child;

  const RigActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.md,
              Space.screen,
              Space.md,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
