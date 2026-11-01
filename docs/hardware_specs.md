# Hardware specifications

How SmartRig knows what is compatible. Decided 1 November 2026 (roadmap 2.A1–2.A4).

## Source

The Amazon API returns titles, prices and ratings, with no structured specs. So specs come from two places:

1. **A curated catalogue** in `lib/data/hardware_catalogue.dart`, for facts that are fixed per model or chipset.
2. **The listing title**, parsed by `lib/services/model_resolver.dart`, for facts that vary per product and are usually stated there.

Paid spec APIs and scraping were not chosen: the first costs money before the app has users, and the second is fragile and may breach site terms. Specs are derived on the device from the saved title, so catalogue updates also apply to builds that are already saved.

## Schema

Defined in `lib/models/hardware_spec.dart`. Null means unknown.

| Part | Field | Unit | Source |
|---|---|---|---|
| CPU | `model` | — | Title |
| CPU | `socket` | enum | Rule from model generation |
| CPU | `maxPowerW` | watts, Intel MTP / AMD PPT | Catalogue |
| GPU | `model` | — | Title |
| GPU | `boardPowerW` | watts, reference card | Catalogue |
| GPU | `lengthMm` | mm | No source yet (varies per card) |
| Motherboard | `chipset`, `formFactor` | — | Title |
| Motherboard | `socket` | enum | Catalogue, from chipset |
| Motherboard | `memoryType` | enum | Title, else platform if it only supports one |
| RAM | `memoryType` | enum | Title |
| PSU | `wattage` | watts | Title |
| Case | `maxFormFactor` | enum | Title (largest size named) |
| Case | `maxGpuLengthMm`, `maxCoolerHeightMm` | mm | No source yet |
| Cooler | `sockets` | set of enums | Title |
| Cooler | `heightMm` | mm | No source yet |

## Confidence rules

| Evidence | Worst result allowed |
|---|---|
| Socket and memory generation | `incompatible` (fixed physical facts) |
| PSU wattage against estimated peak draw | `incompatible` when below peak, `warning` when below the recommended size |
| Case size or cooler sockets from a title | `warning`, because a title may list only some of what is supported |
| Missing or contradictory data | `unknown`, never a pass |

Contradictions are reported rather than guessed: a motherboard whose chipset and stated socket disagree, a listing naming both DDR4 and DDR5, or a PSU title with several wattages.

## Power estimate

Peak draw is CPU max power + GPU board power + 75 W for everything else. The recommended PSU adds 25% headroom and rounds up to the next 50 W. It is an estimate; factory-overclocked GPUs and heavy storage or fan setups can draw more.

## Updating the catalogue

1. Take values from the manufacturer's product page (Intel ARK, AMD, NVIDIA), not retailers.
2. Key entries by the normalized name `ModelResolver` produces, for example `RTX 4070 TI SUPER`.
3. Bump `catalogueVersion` and add resolver tests for any name that could be confused with an existing model.
4. Check the catalogue when new CPU or GPU generations launch.

A model missing from the catalogue is not an error: socket rules still apply, and power checks report `unknown`.

## Not covered yet

- **GPU length, case clearances and cooler height.** The checks exist, but always report `unknown` until a data source exists.
- **RAM configuration** (slot count, maximum capacity, speed limits).
- **CPU support on older boards**, such as a BIOS update being needed; the app shows a reminder only.
