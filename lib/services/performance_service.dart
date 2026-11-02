import 'dart:math' as math;

import '../data/performance_data.dart';
import '../models/component.dart';
import '../models/hardware_spec.dart';
import '../providers/build_provider.dart';
import 'compatibility_service.dart';
import 'model_resolver.dart';

/// Performance result model
class PerformanceResult {
  final double cpuScore;
  final double gpuScore;
  final double systemScore;
  final Map<String, FpsResult> gameFps;
  final int totalPowerW;
  final int recommendedPsuW;
  final BottleneckType bottleneck;
  final double bottleneckPercentage;

  /// False when the part isn't in the gaming index, so its score is a fallback.
  final bool cpuInIndex;
  final bool gpuInIndex;

  const PerformanceResult({
    required this.cpuScore,
    required this.gpuScore,
    required this.systemScore,
    required this.gameFps,
    required this.totalPowerW,
    required this.recommendedPsuW,
    required this.bottleneck,
    required this.bottleneckPercentage,
    this.cpuInIndex = true,
    this.gpuInIndex = true,
  });

  bool get isApproximate => !cpuInIndex || !gpuInIndex;
}

class FpsResult {
  final int fps1080p;
  final int fps1440p;
  final int fps4k;

  const FpsResult({
    required this.fps1080p,
    required this.fps1440p,
    required this.fps4k,
  });
}

enum BottleneckType { cpu, gpu, balanced }

/// Display tier for a gaming index score. Highest first.
enum ScoreTier {
  extreme('Extreme', 150),
  enthusiast('Enthusiast', 110),
  highEnd('High-End', 85),
  midRange('Mid-Range', 60),
  entry('Entry', 35),
  budget('Budget', 0);

  final String label;
  final int minScore;
  const ScoreTier(this.label, this.minScore);

  static ScoreTier fromScore(double score) =>
      ScoreTier.values.firstWhere((tier) => score >= tier.minScore);
}

/// Gaming index score for a part, and whether it came from the index.
class BenchmarkMatch {
  final int score;
  final bool inIndex;

  const BenchmarkMatch(this.score, {required this.inIndex});
}

/// Finds gaming index scores for resolved models.
class BenchmarkLookup {
  const BenchmarkLookup();

  BenchmarkMatch cpu(CpuSpec spec) {
    final score = cpuGamingIndex[spec.model] ?? cpuGamingIndex[spec.baseModel];
    return score == null
        ? const BenchmarkMatch(fallbackCpuIndex, inIndex: false)
        : BenchmarkMatch(score, inIndex: true);
  }

  BenchmarkMatch gpu(GpuSpec spec) {
    final score = gpuGamingIndex[spec.model];
    return score == null
        ? const BenchmarkMatch(fallbackGpuIndex, inIndex: false)
        : BenchmarkMatch(score, inIndex: true);
  }
}

/// Turns index scores into estimates. Pure maths, with assumptions documented
/// in docs/performance_estimates.md.
class PerformanceEstimator {
  /// Index of the reference parts the game profiles are calibrated against.
  static const referenceIndex = 100;

  /// One part being this far behind the other counts as a bottleneck.
  static const balancedRatio = 0.75;

  const PerformanceEstimator();

  /// A game runs at whichever limit is lower: what the GPU can draw at that
  /// resolution, or what the CPU can prepare.
  FpsResult fps(GameProfile game, double cpuScore, double gpuScore) {
    final gpuFps =
        game.referenceGpuFps *
        math.pow(gpuScore / referenceIndex, game.gpuScaling);
    final cpuFps =
        game.referenceCpuFps *
        math.pow(cpuScore / referenceIndex, game.cpuScaling);

    int at(double factor) => math.min(gpuFps * factor, cpuFps).round();

    return FpsResult(
      fps1080p: at(1),
      fps1440p: at(fps1440pFactor),
      fps4k: at(fps4kFactor),
    );
  }

  double systemScore(double cpuScore, double gpuScore) =>
      cpuScore * 0.4 + gpuScore * 0.6;

  (BottleneckType, double) bottleneck(double cpuScore, double gpuScore) {
    if (cpuScore < gpuScore * balancedRatio) {
      return (BottleneckType.cpu, (1 - cpuScore / gpuScore) * 100);
    }
    if (gpuScore < cpuScore * balancedRatio) {
      return (BottleneckType.gpu, (1 - gpuScore / cpuScore) * 100);
    }
    return (BottleneckType.balanced, 0.0);
  }
}

/// Ties model resolution, benchmark lookup and estimation together.
class PerformanceService {
  final ModelResolver _resolver;
  final BenchmarkLookup _benchmarks;
  final PerformanceEstimator _estimator;

  const PerformanceService({
    ModelResolver resolver = const ModelResolver(),
    BenchmarkLookup benchmarks = const BenchmarkLookup(),
    PerformanceEstimator estimator = const PerformanceEstimator(),
  }) : _resolver = resolver,
       _benchmarks = benchmarks,
       _estimator = estimator;

  /// Calculate performance from build state
  PerformanceResult? calculatePerformance(BuildState state) {
    final cpu = state.selectedComponents[ComponentType.cpu];
    final gpu = state.selectedComponents[ComponentType.gpu];

    if (cpu == null || gpu == null) {
      return null;
    }

    final cpuSpec = _resolver.cpu(cpu.name);
    final gpuSpec = _resolver.gpu(gpu.name);
    final cpuMatch = _benchmarks.cpu(cpuSpec);
    final gpuMatch = _benchmarks.gpu(gpuSpec);
    final cpuScore = cpuMatch.score.toDouble();
    final gpuScore = gpuMatch.score.toDouble();

    // Same estimate as the power supply compatibility check.
    final power = PowerEstimate(
      cpuW: cpuSpec.maxPowerW ?? fallbackCpuPowerW,
      gpuW: gpuSpec.boardPowerW ?? fallbackGpuPowerW,
    );
    final (bottleneck, percentage) = _estimator.bottleneck(cpuScore, gpuScore);

    return PerformanceResult(
      cpuScore: cpuScore,
      gpuScore: gpuScore,
      systemScore: _estimator.systemScore(cpuScore, gpuScore),
      gameFps: {
        for (final game in gameProfiles)
          game.name: _estimator.fps(game, cpuScore, gpuScore),
      },
      totalPowerW: power.totalW,
      recommendedPsuW: power.recommendedPsuW,
      bottleneck: bottleneck,
      bottleneckPercentage: percentage,
      cpuInIndex: cpuMatch.inIndex,
      gpuInIndex: gpuMatch.inIndex,
    );
  }
}
