import '../models/component.dart';
import '../providers/build_provider.dart';

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
  /// Reference CPU benchmarks (PassMark scores)
  static const Map<String, double> cpuBenchmarks = {
    'Intel': 28000,
    'AMD': 32000,
    'Core': 25000,
    'Ryzen': 30000,
    'i9': 35000,
    'i7': 28000,
    'i5': 20000,
    'i3': 12000,
  };

  /// Reference GPU benchmarks (PassMark scores)
  static const Map<String, double> gpuBenchmarks = {
    'RTX 4090': 40000,
    'RTX 4080': 35000,
    'RTX 4070': 28000,
    'RTX 3090': 30000,
    'RTX 3080': 25000,
    'RTX 3070': 22000,
    'RTX 3060': 17000,
    'RX 7900': 32000,
    'RX 7800': 26000,
    'RX 6800': 23000,
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
    'RTX 3060': 170,
    'RX 7900': 355,
    'RX 7800': 263,
    'RX 6800': 250,
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
    final cpuTdpValue = _estimateCpuTdp(cpu.name);
    final gpuTdpValue = _estimateGpuTdp(gpu.name);
    final otherPower = 50; // MB, RAM, storage, fans
    final totalPower = cpuTdpValue + gpuTdpValue + otherPower;
    final recommendedPsu = (totalPower * 1.4).round();

    // Bottleneck analysis
    final bottleneck = _analyzeBottleneck(cpuScore, gpuScore);

    return PerformanceResult(
      cpuScore: cpuScore,
      gpuScore: gpuScore,
      systemScore: systemScore,
      gameFps: gameFps,
      totalPowerW: totalPower,
      recommendedPsuW: recommendedPsu,
      bottleneck: bottleneck.$1,
      bottleneckPercentage: bottleneck.$2,
    );
  }

  double _estimateCpuScore(String name) {
    for (final entry in cpuBenchmarks.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 15000; // Default mid-range
  }

  double _estimateGpuScore(String name) {
    for (final entry in gpuBenchmarks.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 15000; // Default mid-range
  }

  int _estimateCpuTdp(String name) {
    for (final entry in cpuTdp.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 65; // Default
  }

  int _estimateGpuTdp(String name) {
    for (final entry in gpuTdp.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 200; // Default
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
