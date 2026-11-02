# Performance estimates

How SmartRig produces scores and FPS (roadmap 2.D2–2.D7). Everything here is an **estimate**, and the app labels it as one.

## Data

`lib/data/performance_data.dart`, versioned by `performanceDataVersion`.

- **Gaming index:** SmartRig's own relative scale, with the Core i9-12900K = 100 for CPUs and the RTX 3080 = 100 for GPUs. The values are editorial judgements of typical gaming performance, not measurements. CPU values favour gaming rather than raw multi-core speed, so X3D chips rank above their multi-core position.
- **Game profiles:** each has the FPS at the reference GPU (1080p, high settings, no upscaling or ray tracing), the FPS the reference CPU can drive, and how strongly each scales.

### Why not published benchmark scores

The old code described its values as PassMark scores. PassMark says its website data [can't be copied and used as your own](https://forums.passmark.com/pc-hardware-and-benchmarks/38618-legality-of-using-your-cpu-benchmark) and [sells data licences](https://www.passmark.com/services/it-consultancy.php), so no PassMark numbers are shipped. To use measured data later, license a source and replace the two index tables; the estimator doesn't need to change.

## Formula

For each game:

```
GPU limit = referenceGpuFps × (gpu index / 100) ^ gpuScaling × resolution factor
CPU limit = referenceCpuFps × (cpu index / 100) ^ cpuScaling
FPS       = the lower of the two
```

Resolution factors are 1.0 at 1080p, 0.72 at 1440p and 0.42 at 4K. They apply only to the GPU limit, because resolution barely changes CPU load. So a slow CPU shows similar FPS at 1080p and 1440p, as in real systems.

- **System score:** 40% CPU index + 60% GPU index.
- **Bottleneck:** one index more than 25% behind the other. The scales are separate, so this is a guide to balance, not a measurement.
- **Power and PSU:** see `docs/hardware_specs.md`.

## Missing data

A model missing from the index gets a fallback score (CPU 85, GPU 50), and the review screen says the result is approximate. Missing power data falls back to 125 W for the CPU and 200 W for the GPU, deliberately on the high side.

## Limitations

Real results depend on game version, settings, drivers, RAM speed, cooling, background software and the specific card. Treat FPS as a rough range, likely off by 20% or more for any one game. Upscaling, frame generation and ray tracing are not modelled. Estimates are useful for comparing builds, not for predicting an exact number.

## Updating

Add new models to the index when they launch, keeping ordering consistent with independent reviews. Bump `performanceDataVersion`, and rerun `test/services/performance_service_test.dart`.
