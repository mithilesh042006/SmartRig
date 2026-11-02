import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/hardware_spec.dart';
import '../providers/build_provider.dart';
import 'model_resolver.dart';

/// Ordered by severity, so the worst result in a report is the overall status.
enum CompatibilityStatus { compatible, unknown, warning, incompatible }

class CompatibilityCheck {
  final String title;
  final CompatibilityStatus status;
  final String message;

  const CompatibilityCheck(this.title, this.status, this.message);
}

class CompatibilityReport {
  final List<CompatibilityCheck> checks;

  const CompatibilityReport(this.checks);

  /// Null until the build has two parts that can be checked against each other.
  CompatibilityStatus? get overall => checks.isEmpty
      ? null
      : checks
            .map((c) => c.status)
            .reduce((a, b) => a.index >= b.index ? a : b);

  int count(CompatibilityStatus status) =>
      checks.where((c) => c.status == status).length;
}

/// System power shared by the compatibility check and the performance review.
class PowerEstimate {
  /// Motherboard, RAM, storage and fans.
  static const otherComponentsW = 75;

  /// Keeps the PSU away from full load and absorbs GPU power spikes.
  static const headroom = 1.25;

  final int totalW;

  const PowerEstimate({required int cpuW, required int gpuW})
    : totalW = cpuW + gpuW + otherComponentsW;

  /// Total with headroom, rounded up to the next PSU size step (50 W).
  int get recommendedPsuW => ((totalW * headroom) / 50).ceil() * 50;
}

/// Specs for the selected parts; null when that part isn't in the build.
class BuildSpecs {
  final CpuSpec? cpu;
  final GpuSpec? gpu;
  final MotherboardSpec? motherboard;
  final RamSpec? ram;
  final PsuSpec? psu;
  final CaseSpec? pcCase;
  final CoolerSpec? cooler;

  const BuildSpecs({
    this.cpu,
    this.gpu,
    this.motherboard,
    this.ram,
    this.psu,
    this.pcCase,
    this.cooler,
  });
}

/// Deterministic build validation, separate from any UI. Unknown data always
/// produces [CompatibilityStatus.unknown], never a pass.
class CompatibilityService {
  final ModelResolver _resolver;

  const CompatibilityService({ModelResolver resolver = const ModelResolver()})
    : _resolver = resolver;

  CompatibilityReport checkBuild(BuildState state) {
    String? name(ComponentType type) => state.selectedComponents[type]?.name;
    T? spec<T>(ComponentType type, T Function(String) resolve) {
      final title = name(type);
      return title == null ? null : resolve(title);
    }

    return check(
      BuildSpecs(
        cpu: spec(ComponentType.cpu, _resolver.cpu),
        gpu: spec(ComponentType.gpu, _resolver.gpu),
        motherboard: spec(ComponentType.motherboard, _resolver.motherboard),
        ram: spec(ComponentType.ram, _resolver.ram),
        psu: spec(ComponentType.psu, _resolver.psu),
        pcCase: spec(ComponentType.pcCase, _resolver.pcCase),
        cooler: spec(ComponentType.cooling, _resolver.cooler),
      ),
    );
  }

  CompatibilityReport check(BuildSpecs specs) {
    final cpu = specs.cpu;
    final gpu = specs.gpu;
    final board = specs.motherboard;
    final ram = specs.ram;
    final psu = specs.psu;
    final pcCase = specs.pcCase;
    final cooler = specs.cooler;

    return CompatibilityReport([
      if (cpu != null && board != null) _socket(cpu, board),
      if (ram != null && board != null) _memory(ram, board),
      if (ram != null && board != null) _ramSlots(ram, board),
      if (cpu != null && gpu != null && psu != null) _power(cpu, gpu, psu),
      if (board != null && pcCase != null) _formFactor(board, pcCase),
      if (gpu != null && pcCase != null) _gpuLength(gpu, pcCase),
      if (cooler != null && cpu != null) _coolerSocket(cooler, cpu),
      if (cooler != null && cpu != null) _coolerCapacity(cooler, cpu),
      if (cooler != null && pcCase != null) _coolerHeight(cooler, pcCase),
    ]);
  }

  CompatibilityCheck _socket(CpuSpec cpu, MotherboardSpec board) {
    const title = 'CPU and motherboard socket';
    if (board.socketConflict) {
      return const CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'The motherboard listing names conflicting sockets. Check the manufacturer page.',
      );
    }
    final cpuSocket = cpu.socket;
    final boardSocket = board.socket;
    if (cpuSocket == null || boardSocket == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'Could not identify the socket of the ${cpuSocket == null ? 'CPU' : 'motherboard'} from its listing.',
      );
    }
    if (cpuSocket != boardSocket) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.incompatible,
        'The CPU uses ${cpuSocket.label}, but the motherboard has ${boardSocket.label}. It will not fit.',
      );
    }
    return CompatibilityCheck(
      title,
      CompatibilityStatus.compatible,
      'Both use ${cpuSocket.label}. Older boards may need a BIOS update for newer CPUs.',
    );
  }

  CompatibilityCheck _memory(RamSpec ram, MotherboardSpec board) {
    const title = 'RAM and motherboard';
    if (ram.conflict || board.memoryConflict) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'The ${ram.conflict ? 'RAM' : 'motherboard'} listing names both DDR4 and DDR5. Check the manufacturer page.',
      );
    }
    final ramType = ram.memoryType;
    final boardType = board.memoryType;
    if (ramType == null || boardType == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        ramType == null
            ? 'Could not identify the RAM generation from its listing.'
            : 'This motherboard platform comes in DDR4 and DDR5 versions, and the listing does not say which.',
      );
    }
    if (ramType != boardType) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.incompatible,
        'The RAM is ${ramType.label}, but the motherboard takes ${boardType.label}. It will not fit.',
      );
    }
    return CompatibilityCheck(
      title,
      CompatibilityStatus.compatible,
      'Both use ${ramType.label}. Speed and capacity limits are not checked.',
    );
  }

  CompatibilityCheck _ramSlots(RamSpec ram, MotherboardSpec board) {
    const title = 'RAM slots';
    final sticks = ram.stickCount;
    final slots = board.ramSlots;
    if (sticks == null || slots == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        sticks == null
            ? 'The RAM listing does not say how many modules it includes.'
            : 'The motherboard listing does not say how many memory slots it has.',
      );
    }
    return sticks > slots
        ? CompatibilityCheck(
            title,
            CompatibilityStatus.incompatible,
            'This $sticks-module kit needs more slots than the motherboard\'s $slots.',
          )
        : CompatibilityCheck(
            title,
            CompatibilityStatus.compatible,
            'The $sticks-module kit fits the motherboard\'s $slots slots.',
          );
  }

  CompatibilityCheck _power(CpuSpec cpu, GpuSpec gpu, PsuSpec psu) {
    const title = 'Power supply capacity';
    final cpuW = cpu.maxPowerW;
    final gpuW = gpu.boardPowerW;
    final wattage = psu.wattage;
    if (wattage == null) {
      return const CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'Could not identify the wattage from the power supply listing.',
      );
    }
    if (cpuW == null || gpuW == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'No power data for this ${cpuW == null ? 'CPU' : 'GPU'} model yet.',
      );
    }
    final power = PowerEstimate(cpuW: cpuW, gpuW: gpuW);
    if (wattage < power.totalW) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.incompatible,
        'Peak draw is about ${power.totalW} W, more than this $wattage W power supply provides.',
      );
    }
    if (wattage < power.recommendedPsuW) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.warning,
        '$wattage W covers the estimated ${power.totalW} W peak with little headroom. ${power.recommendedPsuW} W or more is recommended.',
      );
    }
    return CompatibilityCheck(
      title,
      CompatibilityStatus.compatible,
      '$wattage W covers the estimated ${power.totalW} W peak with headroom.',
    );
  }

  CompatibilityCheck _formFactor(MotherboardSpec board, CaseSpec pcCase) {
    const title = 'Motherboard and case size';
    final boardSize = board.formFactor;
    final caseSize = pcCase.maxFormFactor;
    if (boardSize == null || caseSize == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'The ${boardSize == null ? 'motherboard' : 'case'} listing does not state its size.',
      );
    }
    // Based on what a title happens to name, so never a hard failure.
    if (boardSize.index > caseSize.index) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.warning,
        'The case listing mentions up to ${caseSize.label}, but the motherboard is ${boardSize.label}. It may not fit.',
      );
    }
    return CompatibilityCheck(
      title,
      CompatibilityStatus.compatible,
      'The ${caseSize.label} case takes a ${boardSize.label} motherboard.',
    );
  }

  CompatibilityCheck _gpuLength(GpuSpec gpu, CaseSpec pcCase) {
    const title = 'GPU length';
    final length = gpu.lengthMm;
    final clearance = pcCase.maxGpuLengthMm;
    if (length == null || clearance == null) {
      return const CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'GPU length and case clearance are not available. Compare them on the manufacturer pages.',
      );
    }
    return length > clearance
        ? CompatibilityCheck(
            title,
            CompatibilityStatus.incompatible,
            'The $length mm GPU is longer than the case\'s $clearance mm clearance.',
          )
        : CompatibilityCheck(
            title,
            CompatibilityStatus.compatible,
            'The $length mm GPU fits the case\'s $clearance mm clearance.',
          );
  }

  CompatibilityCheck _coolerSocket(CoolerSpec cooler, CpuSpec cpu) {
    const title = 'Cooler and CPU socket';
    final socket = cpu.socket;
    if (socket == null || cooler.sockets.isEmpty) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        socket == null
            ? 'Could not identify the CPU socket from its listing.'
            : 'The cooler listing does not name its supported sockets.',
      );
    }
    // LGA1851 uses the same cooler mounting as LGA1700.
    final fits =
        cooler.sockets.contains(socket) ||
        (socket == CpuSocket.lga1851 &&
            cooler.sockets.contains(CpuSocket.lga1700));
    return fits
        ? CompatibilityCheck(
            title,
            CompatibilityStatus.compatible,
            'The cooler listing includes ${socket.label}.',
          )
        // Listings often name only some supported sockets.
        : CompatibilityCheck(
            title,
            CompatibilityStatus.warning,
            'The cooler listing does not mention ${socket.label}. Confirm support before buying.',
          );
  }

  CompatibilityCheck _coolerCapacity(CoolerSpec cooler, CpuSpec cpu) {
    const title = 'Cooler capacity';
    final rated = cooler.ratedTdpW;
    final peak = cpu.maxPowerW;
    if (rated == null || peak == null) {
      return CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        rated == null
            ? 'The cooler listing does not state a TDP rating.'
            : 'No power data for this CPU model yet.',
      );
    }
    // Ratings aren't standardized, and CPUs throttle safely, so never a failure.
    return rated < peak
        ? CompatibilityCheck(
            title,
            CompatibilityStatus.warning,
            'The cooler is rated for $rated W, below the CPU\'s $peak W peak. The CPU may slow down under heavy load.',
          )
        : CompatibilityCheck(
            title,
            CompatibilityStatus.compatible,
            'The cooler is rated for $rated W, above the CPU\'s $peak W peak.',
          );
  }

  CompatibilityCheck _coolerHeight(CoolerSpec cooler, CaseSpec pcCase) {
    const title = 'Cooler height';
    final height = cooler.heightMm;
    final clearance = pcCase.maxCoolerHeightMm;
    if (height == null || clearance == null) {
      return const CompatibilityCheck(
        title,
        CompatibilityStatus.unknown,
        'Cooler height and case clearance are not available. Compare them on the manufacturer pages.',
      );
    }
    return height > clearance
        ? CompatibilityCheck(
            title,
            CompatibilityStatus.incompatible,
            'The $height mm cooler is taller than the case\'s $clearance mm clearance.',
          )
        : CompatibilityCheck(
            title,
            CompatibilityStatus.compatible,
            'The $height mm cooler fits the case\'s $clearance mm clearance.',
          );
  }
}

final compatibilityProvider = Provider<CompatibilityReport>((ref) {
  return const CompatibilityService().checkBuild(ref.watch(buildProvider));
});
