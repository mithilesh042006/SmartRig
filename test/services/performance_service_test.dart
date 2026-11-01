import 'package:flutter_test/flutter_test.dart';
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
  return PerformanceService().calculatePerformance(state)!;
}

const _gpu = 'NVIDIA GeForce RTX 3080 10GB';

void main() {
  group('CPU score matching', () {
    test('Intel tier wins over the brand name', () {
      expect(_run(cpu: 'Intel Core i3-12100F', gpu: _gpu).cpuScore, 12000);
      expect(_run(cpu: 'Intel Core i5-12400', gpu: _gpu).cpuScore, 20000);
      expect(_run(cpu: 'Intel® Core™ i7-13700K', gpu: _gpu).cpuScore, 28000);
      expect(_run(cpu: 'Intel Core i9-14900K', gpu: _gpu).cpuScore, 35000);
    });

    test('AMD Ryzen tier wins over the brand name', () {
      expect(_run(cpu: 'AMD Ryzen 3 4100', gpu: _gpu).cpuScore, 12000);
      expect(_run(cpu: 'AMD Ryzen 5 5600X', gpu: _gpu).cpuScore, 20000);
      expect(_run(cpu: 'AMD Ryzen 7 7800X3D', gpu: _gpu).cpuScore, 28000);
      expect(_run(cpu: 'AMD Ryzen 9 7950X', gpu: _gpu).cpuScore, 35000);
    });

    test('falls back to generic keys, then the default', () {
      expect(_run(cpu: 'AMD Ryzen Threadripper', gpu: _gpu).cpuScore, 30000);
      expect(_run(cpu: 'Intel Xeon W-2400', gpu: _gpu).cpuScore, 28000);
      expect(_run(cpu: 'Unknown Processor', gpu: _gpu).cpuScore, 15000);
    });

    test('tier keys only match whole words', () {
      // "Xi5" must not be read as an i5
      expect(_run(cpu: 'Generic Xi5 Chip', gpu: _gpu).cpuScore, 15000);
    });
  });

  group('GPU score matching', () {
    const cpu = 'Intel Core i7-13700K';

    test('specific models win over brand names', () {
      expect(_run(cpu: cpu, gpu: 'ASUS GeForce RTX 4090').gpuScore, 40000);
      expect(
        _run(cpu: cpu, gpu: 'MSI GeForce RTX 4060 Ventus').gpuScore,
        19500,
      );
      expect(_run(cpu: cpu, gpu: 'AMD Radeon RX 7900 XTX').gpuScore, 32000);
      expect(_run(cpu: cpu, gpu: 'Sapphire Radeon RX 7700 XT').gpuScore, 23500);
      expect(_run(cpu: cpu, gpu: 'Intel Arc A770 16GB').gpuScore, 14000);
    });

    test('falls back to brand names, then the default', () {
      expect(_run(cpu: cpu, gpu: 'NVIDIA GeForce GTX 1650').gpuScore, 18000);
      expect(_run(cpu: cpu, gpu: 'AMD Radeon RX 580').gpuScore, 20000);
      expect(_run(cpu: cpu, gpu: 'Mystery Graphics').gpuScore, 15000);
    });
  });

  group('power estimate', () {
    test('uses catalogue power plus 75 W for other parts', () {
      final result = _run(cpu: 'Intel Core i9-14900K', gpu: 'RTX 4060');
      expect(result.totalPowerW, 253 + 115 + 75);
      expect(result.recommendedPsuW, 600);
    });

    test('falls back to tier tables and defaults for unknown models', () {
      final tier = _run(cpu: 'Intel Core i7', gpu: 'Mystery Graphics');
      expect(tier.totalPowerW, 105 + 200 + 75);

      final unknown = _run(cpu: 'Mystery CPU', gpu: 'Mystery Graphics');
      expect(unknown.totalPowerW, 65 + 200 + 75);
    });

    test('agrees with the power supply check', () {
      final result = _run(cpu: 'AMD Ryzen 7 7800X3D', gpu: 'RTX 4070 Super');
      const power = PowerEstimate(cpuW: 162, gpuW: 220);
      expect(result.totalPowerW, power.totalW);
      expect(result.recommendedPsuW, power.recommendedPsuW);
    });
  });
}
