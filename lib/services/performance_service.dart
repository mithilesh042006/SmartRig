import '../models/component.dart';
import '../providers/build_provider.dart';
import 'compatibility_service.dart';
import 'model_resolver.dart';

/// Reference benchmark scores for normalization
class BenchmarkReference {
  static const double referenceGpuScore = 25000; // RTX 3080 level
  static const double referenceCpuScore = 30000; // i9-12900K level
}

/// Game profile for FPS estimation
class GameProfile {
  final String name;
  final int baseFps1080;
  final double gpuScaling;
  final double cpuScaling;

  const GameProfile({
    required this.name,
    required this.baseFps1080,
    this.gpuScaling = 1.0,
    this.cpuScaling = 0.6,
  });
}

/// Resolution multipliers
class Resolution {
  static const double fps1080p = 1.0;
  static const double fps1440p = 0.7;
  static const double fps4k = 0.45;
}

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

  const PerformanceResult({
    required this.cpuScore,
    required this.gpuScore,
    required this.systemScore,
    required this.gameFps,
    required this.totalPowerW,
    required this.recommendedPsuW,
    required this.bottleneck,
    required this.bottleneckPercentage,
  });
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

/// Performance estimation service
class PerformanceService {
  // Lookup tables are matched in insertion order, first match wins, so each
  // table lists specific model/tier keys before generic brand names.

  /// Reference CPU benchmarks (PassMark scores)
  static const Map<String, double> cpuBenchmarks = {
    'i9': 35000,
    'i7': 28000,
    'i5': 20000,
    'i3': 12000,
    'Ryzen 9': 35000,
    'Ryzen 7': 28000,
    'Ryzen 5': 20000,
    'Ryzen 3': 12000,
    'Ryzen': 30000,
    'Core': 25000,
    'Intel': 28000,
    'AMD': 32000,
  };

  /// Reference GPU benchmarks (PassMark scores)
  static const Map<String, double> gpuBenchmarks = {
    'RTX 4090': 40000,
    'RTX 4080': 35000,
    'RTX 4070': 28000,
    'RTX 4060': 19500,
    'RTX 3090': 30000,
    'RTX 3080': 25000,
    'RTX 3070': 22000,
    'RTX 3060': 17000,
    'RX 7900': 32000,
    'RX 7800': 26000,
    'RX 7700': 23500,
    'RX 6800': 23000,
    'RX 6700': 19000,
    'Arc A770': 14000,
    'Arc A750': 13000,
    'Arc A580': 11500,
    'GeForce': 18000,
    'Radeon': 20000,
    'NVIDIA': 20000,
    'AMD': 18000,
  };

  /// Reference TDP values
  static const Map<String, int> cpuTdp = {
    'i9': 125,
    'i7': 105,
    'i5': 65,
    'i3': 60,
    'Ryzen 9': 105,
    'Ryzen 7': 65,
    'Ryzen 5': 65,
  };

  static const Map<String, int> gpuTdp = {
    'RTX 4090': 450,
    'RTX 4080': 320,
    'RTX 4070': 200,
    'RTX 3090': 350,
    'RTX 3080': 320,
    'RTX 3070': 220,
    'RTX 4060': 115,
    'RTX 3060': 170,
    'RX 7900': 355,
    'RX 7800': 263,
    'RX 7700': 245,
    'RX 6800': 250,
    'RX 6700': 230,
    'Arc A770': 225,
    'Arc A750': 225,
    'Arc A580': 185,
  };

  /// Sample games for FPS prediction
  static const List<GameProfile> games = [
    GameProfile(
      name: 'Cyberpunk 2077',
      baseFps1080: 60,
      gpuScaling: 1.0,
      cpuScaling: 0.6,
    ),
    GameProfile(
      name: 'Call of Duty: Warzone',
      baseFps1080: 90,
      gpuScaling: 0.9,
      cpuScaling: 0.7,
    ),
    GameProfile(
      name: 'Fortnite',
      baseFps1080: 144,
      gpuScaling: 0.8,
      cpuScaling: 0.5,
    ),
    GameProfile(
      name: 'Red Dead Redemption 2',
      baseFps1080: 55,
      gpuScaling: 1.0,
      cpuScaling: 0.65,
    ),
    GameProfile(
      name: 'Valorant',
      baseFps1080: 200,
      gpuScaling: 0.5,
      cpuScaling: 0.8,
    ),
  ];

  /// Calculate performance from build state
  PerformanceResult? calculatePerformance(BuildState state) {
    final cpu = state.selectedComponents[ComponentType.cpu];
    final gpu = state.selectedComponents[ComponentType.gpu];

    if (cpu == null || gpu == null) {
      return null;
    }

    // Estimate scores from component names
    final cpuScore = _estimateCpuScore(cpu.name);
    final gpuScore = _estimateGpuScore(gpu.name);

    // System score: 40% CPU, 60% GPU
    final systemScore = (cpuScore * 0.4) + (gpuScore * 0.6);

    // Calculate FPS for each game
    final gameFps = <String, FpsResult>{};
    for (final game in games) {
      gameFps[game.name] = _calculateGameFps(cpuScore, gpuScore, game);
    }

    // Power consumption
    // Catalogue data when the model is known, so this agrees with the PSU check.
    const resolver = ModelResolver();
    final power = PowerEstimate(
      cpuW: resolver.cpu(cpu.name).maxPowerW ?? _estimateCpuTdp(cpu.name),
      gpuW: resolver.gpu(gpu.name).boardPowerW ?? _estimateGpuTdp(gpu.name),
    );

    // Bottleneck analysis
    final bottleneck = _analyzeBottleneck(cpuScore, gpuScore);

    return PerformanceResult(
      cpuScore: cpuScore,
      gpuScore: gpuScore,
      systemScore: systemScore,
      gameFps: gameFps,
      totalPowerW: power.totalW,
      recommendedPsuW: power.recommendedPsuW,
      bottleneck: bottleneck.$1,
      bottleneckPercentage: bottleneck.$2,
    );
  }

  double _estimateCpuScore(String name) =>
      _lookup(cpuBenchmarks, name) ?? 15000; // Default mid-range

  double _estimateGpuScore(String name) =>
      _lookup(gpuBenchmarks, name) ?? 15000; // Default mid-range

  int _estimateCpuTdp(String name) => _lookup(cpuTdp, name) ?? 65;

  int _estimateGpuTdp(String name) => _lookup(gpuTdp, name) ?? 200;

  /// Returns the value of the first key found in [name] as a whole word
  /// (case-insensitive), so "i5" matches "Core i5-12400" but not "Xi5".
  static T? _lookup<T>(Map<String, T> table, String name) {
    for (final entry in table.entries) {
      final pattern = RegExp(
        '(?<![a-z0-9])${RegExp.escape(entry.key)}(?![a-z0-9])',
        caseSensitive: false,
      );
      if (pattern.hasMatch(name)) return entry.value;
    }
    return null;
  }

  FpsResult _calculateGameFps(
    double cpuScore,
    double gpuScore,
    GameProfile game,
  ) {
    // CPU bottleneck factor
    final cpuBottleneckFactor = (cpuScore / gpuScore).clamp(0.7, 1.0);

    // Base FPS calculation
    final gpuMultiplier = gpuScore / BenchmarkReference.referenceGpuScore;

    final fps1080 = (game.baseFps1080 * gpuMultiplier * cpuBottleneckFactor)
        .round();
    final fps1440 = (fps1080 * Resolution.fps1440p).round();
    final fps4k = (fps1080 * Resolution.fps4k).round();

    return FpsResult(
      fps1080p: fps1080.clamp(10, 300),
      fps1440p: fps1440.clamp(10, 200),
      fps4k: fps4k.clamp(10, 120),
    );
  }

  (BottleneckType, double) _analyzeBottleneck(
    double cpuScore,
    double gpuScore,
  ) {
    if (cpuScore < gpuScore * 0.75) {
      final percentage = ((1 - cpuScore / gpuScore) * 100).clamp(0.0, 100.0);
      return (BottleneckType.cpu, percentage.toDouble());
    } else if (gpuScore < cpuScore * 0.75) {
      final percentage = ((1 - gpuScore / cpuScore) * 100).clamp(0.0, 100.0);
      return (BottleneckType.gpu, percentage.toDouble());
    }
    return (BottleneckType.balanced, 0.0);
  }
}
