import '../data/hardware_catalogue.dart';
import '../models/hardware_spec.dart';

/// Maps Amazon listing titles to normalized specs. Anything the title doesn't
/// establish stays null, so callers can report it as unknown.
class ModelResolver {
  const ModelResolver();

  // Uppercase, thousands separators dropped, everything else non-alphanumeric
  // (including ™, ® and hyphens) becomes a single space.
  static String _normalize(String title) => title
      .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '')
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim();

  CpuSpec cpu(String title) {
    final text = _normalize(title);

    final core = RegExp(
      r'\bI([3579]) (\d{4,5})([A-Z]{0,3})\b',
    ).firstMatch(text);
    if (core != null) {
      final number = core[2]!;
      final suffix = core[3]!;
      final generation = number.length == 5
          ? int.parse(number.substring(0, 2))
          : int.parse(number[0]);
      return _cpuSpec(
        'I${core[1]} $number$suffix',
        _isMobileSuffix(suffix) ? null : _intelSocket(generation),
      );
    }

    final ultra = RegExp(
      r'\bULTRA ([579])(?: PROCESSOR)? ?(\d{3})([A-Z]{0,2})\b',
    ).firstMatch(text);
    if (ultra != null) {
      final number = ultra[2]!;
      final suffix = ultra[3]!;
      // Only the 200 series with a desktop suffix uses a socket.
      final desktop = number[0] == '2' && !_isMobileSuffix(suffix);
      return _cpuSpec(
        'ULTRA ${ultra[1]} $number$suffix',
        desktop ? CpuSocket.lga1851 : null,
      );
    }

    final ryzen = RegExp(
      r'\bRYZEN ([3579]) (\d{4})(X3D|XT|GT|GE|X|G|F|E)?\b',
    ).firstMatch(text);
    if (ryzen != null) {
      final number = ryzen[2]!;
      return _cpuSpec(
        'RYZEN ${ryzen[1]} $number${ryzen[3] ?? ''}',
        _ryzenSocket(number[0]),
      );
    }

    return const CpuSpec();
  }

  static CpuSpec _cpuSpec(String model, CpuSocket? socket) => CpuSpec(
    model: model,
    socket: socket,
    maxPowerW:
        cpuMaxPowerW[model] ?? cpuMaxPowerW[CpuSpec(model: model).baseModel],
  );

  static bool _isMobileSuffix(String suffix) =>
      suffix.startsWith('H') ||
      suffix.startsWith('U') ||
      suffix.startsWith('P');

  static CpuSocket? _intelSocket(int generation) => switch (generation) {
    10 || 11 => CpuSocket.lga1200,
    12 || 13 || 14 => CpuSocket.lga1700,
    _ => null,
  };

  static CpuSocket? _ryzenSocket(String series) => switch (series) {
    '1' || '2' || '3' || '4' || '5' => CpuSocket.am4,
    '7' || '8' || '9' => CpuSocket.am5,
    _ => null,
  };

  GpuSpec gpu(String title) {
    final text = _normalize(title);
    final model = _nvidiaModel(text) ?? _amdGpuModel(text) ?? _arcModel(text);
    return GpuSpec(
      model: model,
      boardPowerW: gpuBoardPowerW[model],
      lengthMm: _firstNumber(text, [
        r'\bLENGTH (\d{3}) ?MM\b',
        r'\b(\d{3}) ?MM (?:LONG|LENGTH)\b',
      ]),
    );
  }

  static String? _nvidiaModel(String text) {
    final match = RegExp(
      r'\b(RTX|GTX) ?(\d{4}) ?(TI)? ?(SUPER|S)?\b',
    ).firstMatch(text);
    if (match == null) return null;
    return [
      match[1],
      match[2],
      if (match[3] != null) 'TI',
      if (match[4] != null) 'SUPER',
    ].join(' ');
  }

  static String? _amdGpuModel(String text) {
    final match = RegExp(r'\bRX ?(\d{4}) ?(XTX|XT|GRE)?\b').firstMatch(text);
    if (match == null) return null;
    return ['RX', match[1], if (match[2] != null) match[2]].join(' ');
  }

  static String? _arcModel(String text) {
    final match = RegExp(r'\bARC ?([AB]\d{3})\b').firstMatch(text);
    return match == null ? null : 'ARC ${match[1]}';
  }

  MotherboardSpec motherboard(String title) {
    final text = _normalize(title);
    final chipset = RegExp(
      '\\b(${chipsetSockets.keys.join('|')})[A-Z]{0,2}\\b',
    ).firstMatch(text)?[1];
    final chipsetSocket = chipsetSockets[chipset];
    final named = _namedSockets(text);

    final socketConflict =
        named.length > 1 ||
        (chipsetSocket != null &&
            named.isNotEmpty &&
            !named.contains(chipsetSocket));
    final socket = socketConflict
        ? null
        : chipsetSocket ?? (named.isEmpty ? null : named.first);

    final hasDdr4 = RegExp(r'\b(DDR4|D4)\b').hasMatch(text);
    final hasDdr5 = RegExp(r'\b(DDR5|D5)\b').hasMatch(text);
    final supported = socketMemory[socket] ?? const <MemoryType>{};
    final MemoryType? memoryType;
    if (hasDdr4 && hasDdr5) {
      memoryType = null;
    } else if (hasDdr4) {
      memoryType = MemoryType.ddr4;
    } else if (hasDdr5) {
      memoryType = MemoryType.ddr5;
    } else {
      memoryType = supported.length == 1 ? supported.first : null;
    }

    final formFactor = _largestFormFactor(text);
    final statedSlots = RegExp(r'\b(\d) ?(?:X )?DIMM').firstMatch(text)?[1];

    return MotherboardSpec(
      chipset: chipset,
      socket: socket,
      memoryType: memoryType,
      formFactor: formFactor,
      ramSlots: statedSlots != null
          ? int.parse(statedSlots)
          : formFactor == FormFactor.miniItx
          ? 2
          : null,
      socketConflict: socketConflict,
      memoryConflict: hasDdr4 && hasDdr5,
    );
  }

  RamSpec ram(String title) {
    final text = _normalize(title);
    final hasDdr4 = RegExp(r'\bDDR4\b').hasMatch(text);
    final hasDdr5 = RegExp(r'\bDDR5\b').hasMatch(text);
    if (hasDdr4 && hasDdr5) return const RamSpec(conflict: true);
    final sticks = RegExp(r'\b(\d) ?X ?\d{1,3} ?GB\b').firstMatch(text)?[1];
    return RamSpec(
      memoryType: hasDdr4
          ? MemoryType.ddr4
          : hasDdr5
          ? MemoryType.ddr5
          : null,
      stickCount: sticks == null ? null : int.parse(sticks),
    );
  }

  PsuSpec psu(String title) {
    final values = RegExp(r'\b(\d{3,4}) ?W(?:ATTS?)?\b')
        .allMatches(_normalize(title))
        .map((m) => int.parse(m[1]!))
        .where((w) => w >= 200 && w <= 2500)
        .toSet();
    // Several different wattages (e.g. a product family) can't be trusted.
    return PsuSpec(wattage: values.length == 1 ? values.first : null);
  }

  CaseSpec pcCase(String title) {
    final text = _normalize(title);
    return CaseSpec(
      // Mid and full towers take ATX even when the title doesn't say so.
      maxFormFactor:
          _largestFormFactor(text) ??
          (RegExp(r'\b(MID|FULL) ?TOWER\b').hasMatch(text)
              ? FormFactor.atx
              : null),
      maxGpuLengthMm: _firstNumber(text, [
        r'\b(?:GPU|VGA|GRAPHICS CARDS?)(?: [A-Z]+){0,4} (\d{3}) ?MM\b',
      ]),
      maxCoolerHeightMm: _firstNumber(text, [
        r'\bCPU COOLER(?: [A-Z]+){0,4} (\d{3}) ?MM\b',
      ]),
    );
  }

  CoolerSpec cooler(String title) {
    final text = _normalize(title);
    return CoolerSpec(
      sockets: _namedSockets(text),
      heightMm: _firstNumber(text, [
        r'\bHEIGHT (\d{2,3}) ?MM\b',
        r'\b(\d{2,3}) ?MM (?:HEIGHT|TALL|HIGH)\b',
      ]),
      ratedTdpW: _firstNumber(text, [
        r'\b(\d{2,3}) ?W(?:ATTS?)? TDP\b',
        r'\bTDP(?: UP TO)? (\d{2,3}) ?W',
      ]),
    );
  }

  /// First capture of the first pattern that matches, for measurements a title
  /// only sometimes states.
  static int? _firstNumber(String text, List<String> patterns) {
    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) return int.parse(match[1]!);
    }
    return null;
  }

  static Set<CpuSocket> _namedSockets(String text) => {
    if (RegExp(r'\bAM4\b').hasMatch(text)) CpuSocket.am4,
    if (RegExp(r'\bAM5\b').hasMatch(text)) CpuSocket.am5,
    if (RegExp(r'\bLGA ?1200\b').hasMatch(text)) CpuSocket.lga1200,
    if (RegExp(r'\bLGA ?(1700|17XX)\b').hasMatch(text)) CpuSocket.lga1700,
    if (RegExp(r'\bLGA ?(1851|18XX)\b').hasMatch(text)) CpuSocket.lga1851,
  };

  /// The largest form factor a title names. Smaller names contain "ATX", so
  /// they are removed before looking for a plain ATX.
  static FormFactor? _largestFormFactor(String text) {
    if (RegExp(r'\bE ?ATX\b').hasMatch(text)) return FormFactor.eAtx;
    final microAtx = RegExp(r'\b(MICRO ?|M ?)ATX\b');
    if (RegExp(r'\bATX\b').hasMatch(text.replaceAll(microAtx, ' '))) {
      return FormFactor.atx;
    }
    if (microAtx.hasMatch(text)) return FormFactor.microAtx;
    if (RegExp(r'\b(MINI ?)?ITX\b').hasMatch(text)) return FormFactor.miniItx;
    return null;
  }
}
