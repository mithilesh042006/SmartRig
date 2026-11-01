import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/models/hardware_spec.dart';
import 'package:pc_buildere/providers/build_provider.dart';
import 'package:pc_buildere/services/compatibility_service.dart';

const _service = CompatibilityService();

Component _part(ComponentType type, String name) =>
    Component(id: name, name: name, brand: '', type: type, price: 1);

CompatibilityReport _check(Map<ComponentType, String> parts) =>
    _service.checkBuild(
      BuildState(
        selectedComponents: parts.map(
          (type, name) => MapEntry(type, _part(type, name)),
        ),
      ),
    );

CompatibilityCheck _find(CompatibilityReport report, String title) =>
    report.checks.singleWhere((c) => c.title == title);

const _socket = 'CPU and motherboard socket';
const _memory = 'RAM and motherboard';
const _power = 'Power supply capacity';
const _size = 'Motherboard and case size';
const _gpuLength = 'GPU length';
const _coolerSocket = 'Cooler and CPU socket';
const _coolerHeight = 'Cooler height';

void main() {
  test('a valid build has no problems', () {
    final report = _check({
      ComponentType.cpu: 'AMD Ryzen 7 7800X3D',
      ComponentType.motherboard: 'ASUS B650 ATX Motherboard',
      ComponentType.ram: 'Corsair 32GB DDR5-6000',
      ComponentType.gpu: 'MSI GeForce RTX 4070 SUPER',
      ComponentType.psu: 'Corsair RM750x 750W',
      ComponentType.pcCase: 'Mid Tower ATX Case',
      ComponentType.cooling: 'Air Cooler AM4 AM5 LGA1700',
    });

    expect(_find(report, _socket).status, CompatibilityStatus.compatible);
    expect(_find(report, _memory).status, CompatibilityStatus.compatible);
    expect(_find(report, _power).status, CompatibilityStatus.compatible);
    expect(_find(report, _size).status, CompatibilityStatus.compatible);
    expect(_find(report, _coolerSocket).status, CompatibilityStatus.compatible);
    expect(report.count(CompatibilityStatus.incompatible), 0);
    expect(report.count(CompatibilityStatus.warning), 0);
  });

  test('checks only run once both parts are selected', () {
    expect(_check({}).overall, isNull);
    expect(_check({ComponentType.cpu: 'AMD Ryzen 5 7600X'}).checks, isEmpty);
    expect(
      _check({
        ComponentType.cpu: 'AMD Ryzen 5 7600X',
        ComponentType.ram: 'DDR5 RAM',
      }).checks,
      isEmpty,
    );
  });

  group('socket', () {
    test('mismatch is incompatible and names both sockets', () {
      final check = _find(
        _check({
          ComponentType.cpu: 'Intel Core i5-13600K',
          ComponentType.motherboard: 'MSI B650 Tomahawk',
        }),
        _socket,
      );
      expect(check.status, CompatibilityStatus.incompatible);
      expect(check.message, allOf(contains('LGA1700'), contains('AM5')));
    });

    test('unidentified CPU is unknown, never compatible', () {
      final check = _find(
        _check({
          ComponentType.cpu: 'Mystery Processor',
          ComponentType.motherboard: 'MSI B650 Tomahawk',
        }),
        _socket,
      );
      expect(check.status, CompatibilityStatus.unknown);
    });

    test('conflicting listing is unknown', () {
      final check = _find(
        _check({
          ComponentType.cpu: 'AMD Ryzen 5 7600X',
          ComponentType.motherboard: 'B650 Motherboard LGA1700',
        }),
        _socket,
      );
      expect(check.status, CompatibilityStatus.unknown);
    });
  });

  group('memory', () {
    test('wrong generation is incompatible', () {
      expect(
        _find(
          _check({
            ComponentType.ram: 'Kingston 16GB DDR4',
            ComponentType.motherboard: 'ASUS X670E Hero',
          }),
          _memory,
        ).status,
        CompatibilityStatus.incompatible,
      );
    });

    test('LGA1700 board without a stated generation is unknown', () {
      expect(
        _find(
          _check({
            ComponentType.ram: 'Kingston 16GB DDR5',
            ComponentType.motherboard: 'MSI Z790 Tomahawk',
          }),
          _memory,
        ).status,
        CompatibilityStatus.unknown,
      );
    });

    test('RAM listing naming both generations is unknown', () {
      expect(
        _find(
          _check({
            ComponentType.ram: 'RAM DDR4 DDR5',
            ComponentType.motherboard: 'ASUS B650',
          }),
          _memory,
        ).status,
        CompatibilityStatus.unknown,
      );
    });
  });

  group('power', () {
    Map<ComponentType, String> build(String psu) => {
      ComponentType.cpu: 'Intel Core i9-14900K', // 253 W
      ComponentType.gpu: 'NVIDIA RTX 4090', // 450 W
      ComponentType.psu: psu,
    };

    test('estimate adds other parts, recommendation adds headroom', () {
      const power = PowerEstimate(cpuW: 253, gpuW: 450);
      expect(power.totalW, 778);
      expect(power.recommendedPsuW, 1000);
    });

    test('below peak draw is incompatible', () {
      expect(
        _find(_check(build('550W PSU')), _power).status,
        CompatibilityStatus.incompatible,
      );
    });

    test('at or above peak but under the recommendation is a warning', () {
      expect(
        _find(_check(build('850W PSU')), _power).status,
        CompatibilityStatus.warning,
      );
    });

    test('at the recommendation is compatible', () {
      expect(
        _find(_check(build('1000W PSU')), _power).status,
        CompatibilityStatus.compatible,
      );
    });

    test('unknown wattage or model is unknown', () {
      expect(
        _find(_check(build('Great Power Supply')), _power).status,
        CompatibilityStatus.unknown,
      );
      expect(
        _find(
          _check({
            ComponentType.cpu: 'Mystery CPU',
            ComponentType.gpu: 'NVIDIA RTX 4090',
            ComponentType.psu: '1000W',
          }),
          _power,
        ).status,
        CompatibilityStatus.unknown,
      );
    });
  });

  group('physical fit', () {
    test('board larger than the case is a warning, not a failure', () {
      expect(
        _find(
          _check({
            ComponentType.motherboard: 'B650 ATX',
            ComponentType.pcCase: 'Micro ATX Tower',
          }),
          _size,
        ).status,
        CompatibilityStatus.warning,
      );
    });

    test('case listing without a size is unknown', () {
      expect(
        _find(
          _check({
            ComponentType.motherboard: 'B650 ATX',
            ComponentType.pcCase: 'RGB Glass Tower',
          }),
          _size,
        ).status,
        CompatibilityStatus.unknown,
      );
    });

    test('GPU length uses clearances when data exists', () {
      CompatibilityStatus status(int length, int clearance) => _find(
        _service.check(
          BuildSpecs(
            gpu: GpuSpec(lengthMm: length),
            pcCase: CaseSpec(maxGpuLengthMm: clearance),
          ),
        ),
        _gpuLength,
      ).status;

      expect(status(350, 300), CompatibilityStatus.incompatible);
      expect(status(300, 300), CompatibilityStatus.compatible);
    });

    test('cooler height uses clearances when data exists', () {
      CompatibilityStatus status(int height, int clearance) => _find(
        _service.check(
          BuildSpecs(
            cooler: CoolerSpec(heightMm: height),
            pcCase: CaseSpec(maxCoolerHeightMm: clearance),
          ),
        ),
        _coolerHeight,
      ).status;

      expect(status(170, 160), CompatibilityStatus.incompatible);
      expect(status(160, 160), CompatibilityStatus.compatible);
    });

    test('clearances from listings are unknown today', () {
      final report = _check({
        ComponentType.gpu: 'RTX 4070',
        ComponentType.cooling: 'Air Cooler',
        ComponentType.pcCase: 'ATX Case',
      });
      expect(_find(report, _gpuLength).status, CompatibilityStatus.unknown);
      expect(_find(report, _coolerHeight).status, CompatibilityStatus.unknown);
    });
  });

  group('cooler socket', () {
    test('missing socket is a warning', () {
      expect(
        _find(
          _check({
            ComponentType.cooling: 'Cooler for AM4',
            ComponentType.cpu: 'Intel Core i5-13600K',
          }),
          _coolerSocket,
        ).status,
        CompatibilityStatus.warning,
      );
    });

    test('LGA1851 accepts LGA1700 coolers', () {
      expect(
        _find(
          _check({
            ComponentType.cooling: 'Cooler for LGA1700',
            ComponentType.cpu: 'Intel Core Ultra 7 265K',
          }),
          _coolerSocket,
        ).status,
        CompatibilityStatus.compatible,
      );
    });

    test('listing without sockets is unknown', () {
      expect(
        _find(
          _check({
            ComponentType.cooling: 'Tower Cooler',
            ComponentType.cpu: 'AMD Ryzen 5 7600X',
          }),
          _coolerSocket,
        ).status,
        CompatibilityStatus.unknown,
      );
    });
  });

  test('overall status is the worst check', () {
    expect(
      _check({
        ComponentType.cpu: 'Intel Core i5-13600K',
        ComponentType.motherboard: 'MSI B650',
        ComponentType.ram: 'DDR5',
        ComponentType.pcCase: 'Glass Tower',
      }).overall,
      CompatibilityStatus.incompatible,
    );
    expect(
      _check({
        ComponentType.motherboard: 'B650 ATX',
        ComponentType.pcCase: 'Glass Tower',
      }).overall,
      CompatibilityStatus.unknown,
    );
  });
}
