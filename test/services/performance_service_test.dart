import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/data/hardware_catalogue.dart';
import 'package:pc_buildere/data/performance_data.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/providers/build_provider.dart';
import 'package:pc_buildere/services/compatibility_service.dart';
import 'package:pc_buildere/services/performance_service.dart';

Component _part(ComponentType type, String name) =>
    Component(id: name, name: name, brand: '', type: type, price: 0);

PerformanceResult _run({required String cpu, required String gpu}) {
  final state = BuildState(
    selectedComponents: {
      ComponentType.cpu: _part(ComponentType.cpu, cpu),
      ComponentType.gpu: _part(ComponentType.gpu, gpu),
    },
  );
  return const PerformanceService().calculatePerformance(state)!;
}

const _cpu = 'Intel Core i9-12900K';
const _gpu = 'NVIDIA GeForce RTX 3080 10GB';
const _estimator = PerformanceEstimator();
const _game = GameProfile(
  name: 'Test',
  referenceGpuFps: 100,
  referenceCpuFps: 200,
  gpuScaling: 1.0,
  cpuScaling: 1.0,
);

void main() {
  test('no result until both a CPU and GPU are selected', () {
    final state = BuildState(
      selectedComponents: {ComponentType.cpu: _part(ComponentType.cpu, _cpu)},
    );
    expect(const PerformanceService().calculatePerformance(state), isNull);
  });

  group('score lookup', () {
    test('similar CPUs get their own scores', () {
      expect(_run(cpu: 'Intel Core i5-12400', gpu: _gpu).cpuScore, 85);
      expect(_run(cpu: 'Intel Core i5-13400', gpu: _gpu).cpuScore, 87);
      expect(_run(cpu: 'AMD Ryzen 7 7800X', gpu: _gpu).cpuInIndex, isFalse);
      expect(_run(cpu: 'AMD Ryzen 7 7800X3D', gpu: _gpu).cpuScore, 122);
    });

    test('similar GPUs get their own scores', () {
      expect(_run(cpu: _cpu, gpu: 'RTX 4070').gpuScore, 85);
      expect(_run(cpu: _cpu, gpu: 'RTX 4070 Ti').gpuScore, 108);
      expect(_run(cpu: _cpu, gpu: 'RTX 4070 Super').gpuScore, 98);
      expect(_run(cpu: _cpu, gpu: 'RTX 4070 Ti Super').gpuScore, 118);
    });

    test('F variants use the base model score', () {
      expect(_run(cpu: 'Intel Core i5-12400F', gpu: _gpu).cpuScore, 85);
    });

    test('missing records use the fallback and are flagged', () {
      final result = _run(cpu: 'Mystery CPU', gpu: 'Mystery Graphics');
      expect(result.cpuScore, fallbackCpuIndex);
      expect(result.gpuScore, fallbackGpuIndex);
      expect(result.cpuInIndex, isFalse);
      expect(result.gpuInIndex, isFalse);
      expect(result.isApproximate, isTrue);
    });

    test('known parts are not flagged', () {
      expect(_run(cpu: _cpu, gpu: _gpu).isApproximate, isFalse);
    });

    test('every catalogue part has a score', () {
      expect(
        gpuBoardPowerW.keys.toSet().difference(gpuGamingIndex.keys.toSet()),
        isEmpty,
      );
      expect(
        cpuMaxPowerW.keys.toSet().difference(cpuGamingIndex.keys.toSet()),
        isEmpty,
      );
    });
  });

  group('FPS formula', () {
    test('reference parts give the reference FPS, limited by the GPU', () {
      final fps = _estimator.fps(_game, 100, 100);
      expect(fps.fps1080p, 100);
      expect(fps.fps1440p, 72);
      expect(fps.fps4k, 42);
    });

    test(
      'a fast GPU runs into the CPU limit at every resolution it reaches',
      () {
        final fps = _estimator.fps(_game, 100, 400);
        expect(fps.fps1080p, 200);
        expect(fps.fps1440p, 200);
        expect(fps.fps4k, 168);
      },
    );

    test('scaling changes how much a faster GPU helps', () {
      const weak = GameProfile(
        name: 'Esports',
        referenceGpuFps: 100,
        referenceCpuFps: 1000,
        gpuScaling: 0.5,
        cpuScaling: 1.0,
      );
      expect(_estimator.fps(weak, 100, 400).fps1080p, 200);
      expect(_estimator.fps(_game.withCpuCap(1000), 100, 400).fps1080p, 400);
    });

    test('a faster CPU raises the CPU limit', () {
      expect(_estimator.fps(_game, 50, 1000).fps1080p, 100);
      expect(_estimator.fps(_game, 100, 1000).fps1080p, 200);
    });

    test('results are reproducible', () {
      final a = _run(cpu: _cpu, gpu: _gpu);
      final b = _run(cpu: _cpu, gpu: _gpu);
      expect(a.systemScore, b.systemScore);
      for (final game in gameProfiles) {
        expect(a.gameFps[game.name]!.fps1080p, b.gameFps[game.name]!.fps1080p);
      }
    });

    test('every game gets a result, never higher at a higher resolution', () {
      final result = _run(cpu: 'AMD Ryzen 7 9800X3D', gpu: 'RTX 5090');
      expect(result.gameFps.length, gameProfiles.length);
      for (final fps in result.gameFps.values) {
        expect(fps.fps1440p, lessThanOrEqualTo(fps.fps1080p));
        expect(fps.fps4k, lessThanOrEqualTo(fps.fps1440p));
        expect(fps.fps4k, greaterThan(0));
      }
    });

    test('a faster GPU never lowers FPS', () {
      final slow = _run(cpu: _cpu, gpu: 'RTX 4060');
      final fast = _run(cpu: _cpu, gpu: 'RTX 4090');
      for (final game in gameProfiles) {
        expect(
          fast.gameFps[game.name]!.fps1080p,
          greaterThanOrEqualTo(slow.gameFps[game.name]!.fps1080p),
        );
      }
    });

    test('system score is 40% CPU and 60% GPU', () {
      expect(_estimator.systemScore(100, 200), 160);
    });
  });

  group('bottleneck', () {
    test('close scores are balanced', () {
      expect(_estimator.bottleneck(100, 100).$1, BottleneckType.balanced);
      expect(_estimator.bottleneck(75, 100).$1, BottleneckType.balanced);
      expect(_estimator.bottleneck(75, 100).$2, 0);
    });

    test('a weak CPU is reported with its percentage', () {
      final (type, percentage) = _estimator.bottleneck(50, 100);
      expect(type, BottleneckType.cpu);
      expect(percentage, 50);
    });

    test('a weak GPU is reported with its percentage', () {
      final (type, percentage) = _estimator.bottleneck(100, 50);
      expect(type, BottleneckType.gpu);
      expect(percentage, 50);
    });
  });

  group('power estimate', () {
    test('uses catalogue power plus 75 W for other parts', () {
      final result = _run(cpu: 'Intel Core i9-14900K', gpu: 'RTX 4060');
      expect(result.totalPowerW, 253 + 115 + 75);
      expect(result.recommendedPsuW, 600);
    });

    test('falls back on the high side for unknown models', () {
      final unknown = _run(cpu: 'Mystery CPU', gpu: 'Mystery Graphics');
      expect(unknown.totalPowerW, fallbackCpuPowerW + fallbackGpuPowerW + 75);
    });

    test('agrees with the power supply check', () {
      final result = _run(cpu: 'AMD Ryzen 7 7800X3D', gpu: 'RTX 4070 Super');
      const power = PowerEstimate(cpuW: 162, gpuW: 220);
      expect(result.totalPowerW, power.totalW);
      expect(result.recommendedPsuW, power.recommendedPsuW);
    });
  });

  group('score tiers', () {
    test('boundaries', () {
      expect(ScoreTier.fromScore(150), ScoreTier.extreme);
      expect(ScoreTier.fromScore(149), ScoreTier.enthusiast);
      expect(ScoreTier.fromScore(85), ScoreTier.highEnd);
      expect(ScoreTier.fromScore(60), ScoreTier.midRange);
      expect(ScoreTier.fromScore(35), ScoreTier.entry);
      expect(ScoreTier.fromScore(10), ScoreTier.budget);
      expect(ScoreTier.fromScore(0), ScoreTier.budget);
    });
  });
}

extension on GameProfile {
  GameProfile withCpuCap(int cap) => GameProfile(
    name: name,
    referenceGpuFps: referenceGpuFps,
    referenceCpuFps: cap,
    gpuScaling: gpuScaling,
    cpuScaling: cpuScaling,
  );
}
