# PC Performance Review & Prediction System

## 1. Overview

This document describes the **PC Performance Review & Prediction system** used in the Smart PC Builder app.  
The system provides **estimated performance metrics** for a user-built PC, including CPU/GPU scores, FPS predictions, power consumption, and bottleneck analysis.

⚠️ Note: All results are **estimates**, not real benchmark executions.

---

## 2. Core Performance Metrics

After completing a PC build, the app displays:

- CPU performance score
- GPU performance score
- Combined system score
- Estimated FPS (1080p / 1440p / 4K)
- Power consumption & recommended PSU
- Bottleneck analysis
- Estimated benchmark test results

---

## 3. Reference Data Storage (Firestore)

### 3.1 CPU Benchmarks
```
cpu_benchmarks/{cpuId}
{
  model: "Ryzen 5 5600X",
  passmark: 21500,
  cinebenchSingle: 1600,
  cinebenchMulti: 11500,
  cores: 6,
  threads: 12,
  tdp: 65
}
```

---

### 3.2 GPU Benchmarks
```
gpu_benchmarks/{gpuId}
{
  model: "RTX 3060",
  passmark: 17500,
  timespy: 8700,
  vram: 12,
  tdp: 170
}
```

---

### 3.3 Game Profiles
```
games/{gameId}
{
  name: "Cyberpunk 2077",
  baseFps1080: 60,
  gpuScaling: 1.0,
  cpuScaling: 0.6
}
```

---

## 4. Performance Score Calculations

### 4.1 CPU Score
```
cpuScore = cpu.passmark
```

### 4.2 GPU Score
```
gpuScore = gpu.passmark
```

### 4.3 System Score
```
systemScore = (cpuScore * 0.4) + (gpuScore * 0.6)
```

---

## 5. FPS Prediction System

### 5.1 Resolution Multipliers
```
1080p = 1.0
1440p = 0.7
4K    = 0.45
```

---

### 5.2 FPS Calculation Formula
```
fps =
game.baseFps1080
× (gpuScore / referenceGpuScore)
× resolutionMultiplier
× cpuBottleneckFactor
```

---

### 5.3 CPU Bottleneck Factor
```
cpuBottleneckFactor =
(cpuScore / gpuScore).clamp(0.7, 1.0)
```

---

### 5.4 Example Output
```
Cyberpunk 2077
1080p Ultra → 68 FPS
1440p Ultra → 45 FPS
4K Ultra → 29 FPS
```

---

## 6. Power Consumption Estimation

### 6.1 Total Power Usage
```
totalPower =
cpu.tdp +
gpu.tdp +
50W (motherboard, RAM, storage, fans)
```

---

### 6.2 Recommended PSU
```
recommendedPSU = totalPower × 1.4
```

---

## 7. Bottleneck Analysis

### 7.1 Detection Logic
```
if cpuScore < gpuScore × 0.75:
    CPU bottleneck
elif gpuScore < cpuScore × 0.75:
    GPU bottleneck
else:
    Balanced system
```

---

## 8. Estimated Benchmark Results

The app displays **estimated benchmark scores**, such as:

- PassMark CPU score
- Cinebench R23 (Single & Multi)
- 3DMark Time Spy

⚠️ These are derived from reference data and not actual test runs.

---

## 9. UI Display Recommendations

### Sections
1. Overall Performance Score
2. CPU Performance
3. GPU Performance
4. Gaming FPS (per resolution)
5. Power & PSU Recommendation
6. Bottleneck Analysis

### Flutter Packages
- fl_chart
- percent_indicator

---

## 10. User Transparency & Disclaimer

Always display:

> "Performance results are estimates and may vary based on cooling, drivers, workload, and system configuration."

---

## 11. Future Enhancements

- ML-based FPS prediction
- Real-user FPS data submission
- Backend-powered calculations
- Thermal & noise estimation

---

## 12. Summary

This performance review system provides users with a clear and realistic estimate of how their PC build will perform in real-world scenarios before purchase.
