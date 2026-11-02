// SmartRig's own gaming index and game profiles. These are editorial estimates,
// not measured benchmark results; see docs/performance_estimates.md. Bump
// [performanceDataVersion] on every change.

const performanceDataVersion = '2026.11.1';

/// Relative gaming performance. Intel Core i9-12900K = 100.
const Map<String, int> cpuGamingIndex = {
  'I3 12100': 72,
  'I5 12400': 85,
  'I5 12600K': 95,
  'I7 12700': 95,
  'I7 12700K': 98,
  'I9 12900K': 100,
  'I3 13100': 75,
  'I5 13400': 87,
  'I5 13600K': 105,
  'I7 13700': 105,
  'I7 13700K': 110,
  'I9 13900': 108,
  'I9 13900K': 113,
  'I3 14100': 78,
  'I5 14400': 88,
  'I5 14600K': 107,
  'I7 14700': 107,
  'I7 14700K': 112,
  'I9 14900': 110,
  'I9 14900K': 115,
  'ULTRA 5 245K': 100,
  'ULTRA 7 265K': 105,
  'ULTRA 9 285K': 108,
  'RYZEN 5 5500': 70,
  'RYZEN 5 5600': 80,
  'RYZEN 5 5600X': 82,
  'RYZEN 7 5700X': 82,
  'RYZEN 7 5800X': 85,
  'RYZEN 7 5800X3D': 102,
  'RYZEN 9 5900X': 86,
  'RYZEN 9 5950X': 86,
  'RYZEN 5 7600': 95,
  'RYZEN 5 7600X': 98,
  'RYZEN 7 7700': 97,
  'RYZEN 7 7700X': 100,
  'RYZEN 7 7800X3D': 122,
  'RYZEN 9 7900': 97,
  'RYZEN 9 7900X': 101,
  'RYZEN 9 7950X': 103,
  'RYZEN 9 7950X3D': 120,
  'RYZEN 5 9600X': 104,
  'RYZEN 7 9700X': 106,
  'RYZEN 7 9800X3D': 135,
  'RYZEN 9 9900X': 106,
  'RYZEN 9 9900X3D': 130,
  'RYZEN 9 9950X': 108,
  'RYZEN 9 9950X3D': 133,
};

/// Relative gaming performance. NVIDIA RTX 3080 = 100.
const Map<String, int> gpuGamingIndex = {
  'RTX 5090': 200,
  'RTX 5080': 150,
  'RTX 5070 TI': 130,
  'RTX 5070': 105,
  'RTX 5060 TI': 85,
  'RTX 5060': 72,
  'RTX 4090': 170,
  'RTX 4080 SUPER': 135,
  'RTX 4080': 130,
  'RTX 4070 TI SUPER': 118,
  'RTX 4070 TI': 108,
  'RTX 4070 SUPER': 98,
  'RTX 4070': 85,
  'RTX 4060 TI': 68,
  'RTX 4060': 55,
  'RTX 3090 TI': 112,
  'RTX 3090': 105,
  'RTX 3080 TI': 110,
  'RTX 3080': 100,
  'RTX 3070 TI': 82,
  'RTX 3070': 75,
  'RTX 3060 TI': 66,
  'RTX 3060': 50,
  'RTX 3050': 33,
  'GTX 1660 SUPER': 33,
  'GTX 1660 TI': 33,
  'GTX 1660': 29,
  'GTX 1650': 22,
  'RX 9070 XT': 125,
  'RX 9070': 105,
  'RX 9070 GRE': 90,
  'RX 9060 XT': 72,
  'RX 7900 XTX': 135,
  'RX 7900 XT': 115,
  'RX 7900 GRE': 100,
  'RX 7800 XT': 92,
  'RX 7700 XT': 78,
  'RX 7600': 50,
  'RX 6950 XT': 110,
  'RX 6900 XT': 105,
  'RX 6800 XT': 98,
  'RX 6800': 82,
  'RX 6750 XT': 66,
  'RX 6700 XT': 62,
  'RX 6650 XT': 46,
  'RX 6600': 38,
  'ARC B580': 52,
  'ARC B570': 45,
  'ARC A770': 48,
  'ARC A750': 44,
  'ARC A580': 38,
  'ARC A380': 15,
};

/// Used when a model isn't in the index above; such results are flagged as
/// approximate in the UI.
const fallbackCpuIndex = 85;
const fallbackGpuIndex = 50;

/// Power assumed for a model missing from the catalogue. Deliberately on the
/// high side, so a PSU recommendation isn't undersized.
const fallbackCpuPowerW = 125;
const fallbackGpuPowerW = 200;

class GameProfile {
  final String name;

  /// 1080p high-settings FPS with the reference GPU (index 100), no upscaling.
  final int referenceGpuFps;

  /// FPS the reference CPU (index 100) can drive, regardless of GPU.
  final int referenceCpuFps;

  /// How strongly FPS follows GPU or CPU speed: 1.0 is proportional, lower
  /// means extra speed helps less.
  final double gpuScaling;
  final double cpuScaling;

  const GameProfile({
    required this.name,
    required this.referenceGpuFps,
    required this.referenceCpuFps,
    required this.gpuScaling,
    required this.cpuScaling,
  });
}

const List<GameProfile> gameProfiles = [
  GameProfile(
    name: 'Cyberpunk 2077',
    referenceGpuFps: 110,
    referenceCpuFps: 140,
    gpuScaling: 1.0,
    cpuScaling: 0.9,
  ),
  GameProfile(
    name: 'Call of Duty: Warzone',
    referenceGpuFps: 150,
    referenceCpuFps: 180,
    gpuScaling: 0.9,
    cpuScaling: 0.9,
  ),
  GameProfile(
    name: 'Fortnite',
    referenceGpuFps: 170,
    referenceCpuFps: 260,
    gpuScaling: 0.8,
    cpuScaling: 0.8,
  ),
  GameProfile(
    name: 'Red Dead Redemption 2',
    referenceGpuFps: 115,
    referenceCpuFps: 170,
    gpuScaling: 1.0,
    cpuScaling: 0.7,
  ),
  GameProfile(
    name: 'Valorant',
    referenceGpuFps: 450,
    referenceCpuFps: 480,
    gpuScaling: 0.5,
    cpuScaling: 1.0,
  ),
];

/// GPU-limited FPS at each resolution, relative to 1080p. The CPU limit doesn't
/// change with resolution.
const fps1440pFactor = 0.72;
const fps4kFactor = 0.42;
