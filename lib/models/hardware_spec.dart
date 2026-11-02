// Normalized hardware specifications. A null field always means "unknown";
// see docs/hardware_specs.md for where each field comes from.

enum CpuSocket {
  am4('AM4'),
  am5('AM5'),
  lga1200('LGA1200'),
  lga1700('LGA1700'),
  lga1851('LGA1851');

  final String label;
  const CpuSocket(this.label);
}

enum MemoryType {
  ddr4('DDR4'),
  ddr5('DDR5');

  final String label;
  const MemoryType(this.label);
}

/// Ordered smallest to largest, so a case fits any board up to its maximum.
enum FormFactor {
  miniItx('Mini-ITX'),
  microAtx('Micro-ATX'),
  atx('ATX'),
  eAtx('E-ATX');

  final String label;
  const FormFactor(this.label);
}

class CpuSpec {
  final String? model;
  final CpuSocket? socket;

  /// Peak package power in watts (Intel MTP / AMD PPT), not base TDP.
  final int? maxPowerW;

  const CpuSpec({this.model, this.socket, this.maxPowerW});

  /// The model without a trailing "F", which only removes integrated graphics.
  String? get baseModel => model?.replaceFirst(RegExp(r'F$'), '');
}

class GpuSpec {
  final String? model;
  final int? boardPowerW;
  final int? lengthMm;

  const GpuSpec({this.model, this.boardPowerW, this.lengthMm});
}

class MotherboardSpec {
  final String? chipset;
  final CpuSocket? socket;
  final MemoryType? memoryType;
  final FormFactor? formFactor;

  /// Memory slots, from the title or a size that fixes the count (Mini-ITX).
  final int? ramSlots;

  /// The listing's chipset and stated socket disagree.
  final bool socketConflict;

  /// The listing names both memory generations.
  final bool memoryConflict;

  const MotherboardSpec({
    this.chipset,
    this.socket,
    this.memoryType,
    this.formFactor,
    this.ramSlots,
    this.socketConflict = false,
    this.memoryConflict = false,
  });
}

class RamSpec {
  final MemoryType? memoryType;

  /// Modules in the kit, from a title like "32GB (2x16GB)".
  final int? stickCount;

  /// The listing names both memory generations.
  final bool conflict;

  const RamSpec({this.memoryType, this.stickCount, this.conflict = false});
}

class PsuSpec {
  final int? wattage;

  const PsuSpec({this.wattage});
}

class CaseSpec {
  final FormFactor? maxFormFactor;
  final int? maxGpuLengthMm;
  final int? maxCoolerHeightMm;

  const CaseSpec({
    this.maxFormFactor,
    this.maxGpuLengthMm,
    this.maxCoolerHeightMm,
  });
}

class CoolerSpec {
  /// Sockets named in the listing; empty when it names none.
  final Set<CpuSocket> sockets;
  final int? heightMm;

  /// Heat the cooler is rated for, in watts.
  final int? ratedTdpW;

  const CoolerSpec({this.sockets = const {}, this.heightMm, this.ratedTdpW});
}
