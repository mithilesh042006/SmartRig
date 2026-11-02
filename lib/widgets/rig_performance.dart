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
    ScoreTier.enthusiast => c.accent,
    ScoreTier.highEnd => c.success,
    ScoreTier.midRange => c.warning,
    ScoreTier.entry => c.warning,
    ScoreTier.budget => c.error,
  };
}

/// An animated open-bottomed arc. [progress] runs from 0 to 1.
class RigGauge extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final String semanticLabel;

  /// Sweep in radians; a full circle is used for compact progress rings.
  final double sweep;

  const RigGauge({
    super.key,
    required this.progress,
    required this.color,
    required this.semanticLabel,
    this.size = 180,
    this.strokeWidth = 14,
    this.child,
    this.sweep = math.pi * 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.rig.surfaceRaised;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: Motion.of(context, Motion.slow),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => CustomPaint(
            painter: _GaugePainter(
              value: value,
              color: color,
              track: track,
              strokeWidth: strokeWidth,
              sweep: sweep,
            ),
            child: child,
          ),
          // Large text settings scale the label down rather than overflow the ring.
          child: Padding(
            padding: EdgeInsets.all(strokeWidth + Space.xs),
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
  final double strokeWidth;
  final double sweep;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final start = math.pi / 2 + (math.pi * 2 - sweep) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(rect, start, sweep * value, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.sweep != sweep;
}

/// Score card for the CPU or GPU.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RigIconBox(icon: icon, color: color, size: 36),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(label, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(score.toStringAsFixed(0), style: context.metric(32)),
          Text(tier, style: context.text.bodySmall),
          const SizedBox(height: Space.md),
          _Bar(progress: score / 200, color: color),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double progress;
  final Color color;

  const _Bar({required this.progress, required this.color});

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
            minHeight: 6,
            color: color,
            backgroundColor: context.rig.surfaceRaised,
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
  final Color? color;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RigCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RigIconBox(icon: icon, color: color, size: 36),
          const SizedBox(height: Space.md),
          Text(value, style: context.metric(24, color: color)),
          const SizedBox(height: Space.xs),
          Text(label, style: context.text.bodySmall),
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
  final c = context.rig;
  return [
    _Resolution('1080p', c.accent, (f) => f.fps1080p),
    _Resolution('1440p', c.accentAlt, (f) => f.fps1440p),
    _Resolution('4K', c.success, (f) => f.fps4k),
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
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: resolution.color,
                  borderRadius: BorderRadius.circular(3),
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
    BottleneckType.gpu => ('GPU bottleneck ($percent%)', c.warning, Icons.tv),
    BottleneckType.balanced => ('Balanced', c.success, Icons.check_circle),
  };
}
