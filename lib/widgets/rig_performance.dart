import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../theme/app_tokens.dart';
import 'rig_surfaces.dart';

Color scoreColor(BuildContext context, double score) {
  final c = context.rig;
  return switch (ScoreTier.fromScore(score)) {
    ScoreTier.extreme => c.accentAlt,
    ScoreTier.enthusiast => c.success,
    ScoreTier.highEnd => c.success,
    ScoreTier.midRange => c.warning,
    ScoreTier.entry => c.warning,
    ScoreTier.budget => c.error,
  };
}

/// An animated arc of chunky blocks. [progress] runs from 0 to 1.
class RigGauge extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final int segments;
  final Widget? child;
  final String semanticLabel;

  const RigGauge({
    super.key,
    required this.progress,
    required this.color,
    required this.semanticLabel,
    this.size = 260,
    this.segments = 16,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.rig.surfaceRaised;
    final block = _GaugePainter.blockDepth(size);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 0.68,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: Motion.of(context, Motion.slow),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => CustomPaint(
            painter: _GaugePainter(
              value: value,
              color: color,
              track: track,
              segments: segments,
            ),
            child: child,
          ),
          // Large text settings scale the label down rather than overflow.
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              block + Space.md,
              block + Space.md,
              block + Space.md,
              0,
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final int segments;

  /// 220 degrees, leaving the gap at the bottom.
  static const _sweep = math.pi * 1.22;

  static double blockDepth(double size) => size * 0.15;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final depth = blockDepth(size.width);
    final radius = size.width / 2 - depth / 2;
    final center = Offset(size.width / 2, size.width / 2);
    final slot = _sweep / segments;
    final thickness = math.max(radius * slot * 0.76, 2.0);
    final start = -math.pi / 2 - _sweep / 2;
    final filled = value * segments;
    final paint = Paint();

    for (var i = 0; i < segments; i++) {
      final amount = (filled - i).clamp(0.0, 1.0);
      paint.color = Color.lerp(track, color, amount)!;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + slot * (i + 0.5));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(radius, 0),
            width: depth,
            height: thickness,
          ),
          Radius.circular(thickness * 0.38),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.segments != segments;
}

/// Score block for the CPU or GPU, filled with the part's colour.
class ComponentScoreCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double score;
  final Color color;

  const ComponentScoreCard({
    super.key,
    required this.label,
    required this.icon,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tier = ScoreTier.fromScore(score).label;
    return RigCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RigPalette.ink, size: 20),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall!.copyWith(
                    color: RigPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            score.toStringAsFixed(0),
            style: context.metric(42, color: RigPalette.ink),
          ),
          Text(
            tier,
            style: context.text.bodySmall!.copyWith(color: RigPalette.ink),
          ),
          const SizedBox(height: Space.md),
          _Bar(progress: score / 200),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double progress;

  const _Bar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: Motion.of(context, Motion.slow),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: RigPalette.ink,
            backgroundColor: RigPalette.ink.withValues(alpha: 0.16),
          ),
        ),
      ),
    );
  }
}

/// A labelled figure with an icon, such as power draw.
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// The block's fill.
  final Color color;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RigCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RigPalette.ink, size: 24),
          const SizedBox(height: Space.lg),
          Text(value, style: context.metric(28, color: RigPalette.ink)),
          const SizedBox(height: Space.xs),
          Text(
            label,
            style: context.text.bodySmall!.copyWith(color: RigPalette.ink),
          ),
        ],
      ),
    );
  }
}

class _Resolution {
  final String label;
  final Color color;
  final int Function(FpsResult) read;

  const _Resolution(this.label, this.color, this.read);
}

List<_Resolution> _resolutions(BuildContext context) {
  return [
    _Resolution('1080p', RigPalette.volt, (f) => f.fps1080p),
    _Resolution('1440p', RigPalette.tangerine, (f) => f.fps1440p),
    _Resolution('4K', RigPalette.lilac, (f) => f.fps4k),
  ];
}

/// A compact name that fits under a chart bar.
String shortGameName(String name) => switch (name) {
  'Call of Duty: Warzone' => 'Warzone',
  'Red Dead Redemption 2' => 'RDR 2',
  'Cyberpunk 2077' => 'Cyberpunk',
  _ => name,
};

/// Grouped FPS bars for each game at each resolution.
class FpsChart extends StatelessWidget {
  final Map<String, FpsResult> gameFps;

  const FpsChart({super.key, required this.gameFps});

  /// Highest FPS rounded up to the next 50, so no bar is clipped.
  double get _maxY {
    final highest = gameFps.values
        .expand((fps) => [fps.fps1080p, fps.fps1440p, fps.fps4k])
        .fold(0, (max, fps) => fps > max ? fps : max);
    return ((highest / 50).floor() + 1) * 50.0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final games = gameFps.entries.toList();
    final resolutions = _resolutions(context);
    final maxY = _maxY;
    final interval = maxY <= 200 ? 50.0 : 100.0;

    return Semantics(
      label:
          'Chart of estimated frames per second. The table below lists the '
          'same values.',
      excludeSemantics: true,
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.textPrimary,
                getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                  '${shortGameName(games[group.x].key)}\n'
                  '${resolutions[rodIndex].label}: ${rod.toY.round()} FPS',
                  context.text.labelSmall!.copyWith(color: c.background),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= games.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: Text(
                        shortGameName(games[index].key),
                        maxLines: 1,
                        style: context.text.labelSmall!.copyWith(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: Text('FPS', style: context.text.labelSmall),
                axisNameSize: 18,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: context.text.labelSmall,
                  ),
                ),
              ),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: c.border, strokeWidth: 1),
            ),
            barGroups: [
              for (var i = 0; i < games.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    for (final resolution in resolutions)
                      BarChartRodData(
                        toY: resolution.read(games[i].value).toDouble(),
                        color: resolution.color,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          duration: Motion.of(context, Motion.normal),
        ),
      ),
    );
  }
}

class FpsLegend extends StatelessWidget {
  const FpsLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      alignment: WrapAlignment.center,
      children: [
        for (final resolution in _resolutions(context))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: resolution.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.xs + 2),
              Text(resolution.label, style: context.text.labelMedium),
            ],
          ),
      ],
    );
  }
}

/// The chart's values in aligned rows, readable at any text size.
class FpsTable extends StatelessWidget {
  final Map<String, FpsResult> gameFps;

  const FpsTable({super.key, required this.gameFps});

  @override
  Widget build(BuildContext context) {
    final resolutions = _resolutions(context);

    Widget cell(String text, TextStyle style) => SizedBox(
      width: 52,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('Game', style: context.text.labelSmall)),
            for (final resolution in resolutions)
              cell(resolution.label, context.text.labelSmall!),
          ],
        ),
        const SizedBox(height: Space.sm),
        for (final entry in gameFps.entries)
          Semantics(
            label:
                '${entry.key}: ${resolutions.map((r) => '${r.read(entry.value)} FPS at ${r.label}').join(', ')}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: context.text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final resolution in resolutions)
                    cell(
                      resolution.read(entry.value).toString(),
                      context.metric(14),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// What the bottleneck classification means, for any screen that shows it.
(String, Color, IconData) bottleneckSummary(
  BuildContext context,
  PerformanceResult result,
) {
  final c = context.rig;
  final percent = result.bottleneckPercentage.toStringAsFixed(0);
  return switch (result.bottleneck) {
    BottleneckType.cpu => (
      'CPU bottleneck ($percent%)',
      c.warning,
      Icons.memory,
    ),
    BottleneckType.gpu => (
      'GPU bottleneck ($percent%)',
      c.warning,
      Icons.videogame_asset,
    ),
    BottleneckType.balanced => ('Balanced', c.success, Icons.check_circle),
  };
}
