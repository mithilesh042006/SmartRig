// Curated hardware data. Keys are the normalized model names produced by
// ModelResolver. Bump [catalogueVersion] on every data change; the review
// process is in docs/hardware_specs.md.
import '../models/hardware_spec.dart';

const catalogueVersion = '2026.11.3';

/// Peak package power in watts (Intel MTP / AMD PPT). "F" variants share the
/// entry of the same model without integrated graphics.
const Map<String, int> cpuMaxPowerW = {
  // Intel 12th gen
  'I3 12100': 89,
  'I5 12400': 117,
  'I5 12600K': 150,
  'I7 12700': 180,
  'I7 12700K': 190,
  'I9 12900K': 241,
  // Intel 13th gen
  'I3 13100': 110,
  'I5 13400': 148,
  'I5 13600K': 181,
  'I7 13700': 219,
  'I7 13700K': 253,
  'I9 13900': 219,
  'I9 13900K': 253,
  // Intel 14th gen
  'I3 14100': 110,
  'I5 14400': 148,
  'I5 14600K': 181,
  'I7 14700': 219,
  'I7 14700K': 253,
  'I9 14900': 219,
  'I9 14900K': 253,
  // Intel Core Ultra 200S
  'ULTRA 5 245K': 159,
  'ULTRA 7 265K': 250,
  'ULTRA 9 285K': 250,
  // AMD AM4
  'RYZEN 5 5500': 76,
  'RYZEN 5 5600': 76,
  'RYZEN 5 5600X': 76,
  'RYZEN 7 5700X': 76,
  'RYZEN 7 5800X': 142,
  'RYZEN 7 5800X3D': 142,
  'RYZEN 9 5900X': 142,
  'RYZEN 9 5950X': 142,
  // AMD AM5
  'RYZEN 5 7600': 88,
  'RYZEN 5 7600X': 142,
  'RYZEN 7 7700': 88,
  'RYZEN 7 7700X': 142,
  'RYZEN 7 7800X3D': 162,
  'RYZEN 9 7900': 88,
  'RYZEN 9 7900X': 230,
  'RYZEN 9 7950X': 230,
  'RYZEN 9 7950X3D': 162,
  'RYZEN 5 9600X': 88,
  'RYZEN 7 9700X': 88,
  'RYZEN 7 9800X3D': 162,
  'RYZEN 9 9900X': 162,
  'RYZEN 9 9900X3D': 162,
  'RYZEN 9 9950X': 200,
  'RYZEN 9 9950X3D': 200,
};

/// Reference total board power in watts. Factory-overclocked cards can draw
/// somewhat more. Where a model has several versions, this is the highest, so
/// PSU advice errs on the safe side.
const Map<String, int> gpuBoardPowerW = {
  // NVIDIA
  'RTX 5090': 575,
  'RTX 5080': 360,
  'RTX 5070 TI': 300,
  'RTX 5070': 250,
  'RTX 5060 TI': 180,
  'RTX 5060': 145,
  'RTX 4090': 450,
  'RTX 4080 SUPER': 320,
  'RTX 4080': 320,
  'RTX 4070 TI SUPER': 285,
  'RTX 4070 TI': 285,
  'RTX 4070 SUPER': 220,
  'RTX 4070': 200,
  'RTX 4060 TI': 165,
  'RTX 4060': 115,
  'RTX 3090 TI': 450,
  'RTX 3090': 350,
  'RTX 3080 TI': 350,
  'RTX 3080': 320,
  'RTX 3070 TI': 290,
  'RTX 3070': 220,
  'RTX 3060 TI': 200,
  'RTX 3060': 170,
  'RTX 3050': 130,
  'GTX 1660 SUPER': 125,
  'GTX 1660 TI': 120,
  'GTX 1660': 120,
  'GTX 1650': 75,
  // AMD
  'RX 9070 XT': 304,
  'RX 9070': 220,
  'RX 9070 GRE': 220,
  'RX 9060 XT': 160,
  'RX 7900 XTX': 355,
  'RX 7900 XT': 315,
  'RX 7900 GRE': 260,
  'RX 7800 XT': 263,
  'RX 7700 XT': 245,
  'RX 7600': 165,
  'RX 6950 XT': 335,
  'RX 6900 XT': 300,
  'RX 6800 XT': 300,
  'RX 6800': 250,
  'RX 6750 XT': 250,
  'RX 6700 XT': 230,
  'RX 6650 XT': 180,
  'RX 6600': 132,
  // Intel
  'ARC B580': 190,
  'ARC B570': 150,
  'ARC A770': 225,
  'ARC A750': 225,
  'ARC A580': 175,
  'ARC A380': 75,
};

/// Socket fixed by each desktop motherboard chipset.
const Map<String, CpuSocket> chipsetSockets = {
  'A320': CpuSocket.am4,
  'B350': CpuSocket.am4,
  'X370': CpuSocket.am4,
  'B450': CpuSocket.am4,
  'X470': CpuSocket.am4,
  'A520': CpuSocket.am4,
  'B550': CpuSocket.am4,
  'X570': CpuSocket.am4,
  'A620': CpuSocket.am5,
  'B650': CpuSocket.am5,
  'X670': CpuSocket.am5,
  'B840': CpuSocket.am5,
  'B850': CpuSocket.am5,
  'X870': CpuSocket.am5,
  'H410': CpuSocket.lga1200,
  'B460': CpuSocket.lga1200,
  'H470': CpuSocket.lga1200,
  'Z490': CpuSocket.lga1200,
  'H510': CpuSocket.lga1200,
  'B560': CpuSocket.lga1200,
  'H570': CpuSocket.lga1200,
  'Z590': CpuSocket.lga1200,
  'H610': CpuSocket.lga1700,
  'B660': CpuSocket.lga1700,
  'H670': CpuSocket.lga1700,
  'Z690': CpuSocket.lga1700,
  'B760': CpuSocket.lga1700,
  'H770': CpuSocket.lga1700,
  'Z790': CpuSocket.lga1700,
  'H810': CpuSocket.lga1851,
  'B860': CpuSocket.lga1851,
  'Z890': CpuSocket.lga1851,
};

/// Memory generations each socket's platform supports.
const Map<CpuSocket, Set<MemoryType>> socketMemory = {
  CpuSocket.am4: {MemoryType.ddr4},
  CpuSocket.am5: {MemoryType.ddr5},
  CpuSocket.lga1200: {MemoryType.ddr4},
  CpuSocket.lga1700: {MemoryType.ddr4, MemoryType.ddr5},
  CpuSocket.lga1851: {MemoryType.ddr5},
};
