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
| GPU | `lengthMm` | mm | Title, when stated (varies per card) |
| Motherboard | `chipset`, `formFactor` | — | Title |
| Motherboard | `socket` | enum | Catalogue, from chipset |
| Motherboard | `memoryType` | enum | Title, else platform if it only supports one |
| Motherboard | `ramSlots` | count | Title, or 2 for Mini-ITX |
| RAM | `memoryType` | enum | Title |
| RAM | `stickCount` | count | Title |
| PSU | `wattage` | watts | Title |
| Case | `maxFormFactor` | enum | Title (largest size named; mid and full towers count as ATX) |
| Case | `maxGpuLengthMm`, `maxCoolerHeightMm` | mm | Title, when stated |
| Cooler | `sockets` | set of enums | Title |
| Cooler | `heightMm` | mm | Title, when stated |
| Cooler | `ratedTdpW` | watts | Title, when stated |

## Confidence rules

| Evidence | Worst result allowed |
|---|---|
| Socket, memory generation, and module count against slots | `incompatible` (fixed physical facts) |
| GPU length and cooler height against a stated clearance | `incompatible` |
| PSU wattage against estimated peak draw | `incompatible` when below peak, `warning` when below the recommended size |
| Case size or cooler sockets from a title | `warning`, because a title may list only some of what is supported |
| Cooler TDP rating against CPU peak | `warning`, because ratings aren't standardized and CPUs throttle safely |
| Missing or contradictory data | `unknown`, never a pass |

Contradictions are reported rather than guessed: a motherboard whose chipset and stated socket disagree, a listing naming both DDR4 and DDR5, or a PSU title with several wattages.

## Power estimate

Peak draw is CPU max power + GPU board power + 75 W for everything else. The recommended PSU adds 25% headroom and rounds up to the next 50 W. It is an estimate; factory-overclocked GPUs and heavy storage or fan setups can draw more.

## Checked against

Checked 1 November 2026. Real-title coverage is locked in by `test/services/real_listings_test.dart`, using 80 Amazon titles from `test/fixtures/amazon_titles.json`.

- **Intel maximum turbo power:** compared with Wikipedia's Alder Lake, Raptor Lake and Arrow Lake tables and retailer listings. This corrected the i3-13100 and i3-14100 to 110 W. The i5-12400, i5-14400, i9-12900K, i9-13900K and i9-14900K were not in the part of those tables that could be read, so they rest on other sources or memory.
- **AMD PPT:** AMD publishes TDP more readily than PPT. The 9950X3D's 200 W comes from reviews. The 9900X3D's 162 W is inferred from its 120 W TDP, using the same ratio as other 120 W parts.
- **GPU board power:** compared with Wikipedia's per-series tables for RTX 50, 40 and 30, RX 9000, 7000 and 6000, and Intel Arc. This corrected the RX 6650 XT and Arc A580. Models with several versions use the highest value (RTX 3050, RTX 4060 Ti, RX 9060 XT). Not in the parts of those tables that could be read: RTX 4080 Super, 4070 Ti Super, 3090, 3080 Ti, 3080, RX 6900 XT, 6800, Arc A770, A380, and GTX 1660 Super, 1660 Ti, 1650.
- **Sockets and chipsets:** the rules were not compared line by line; 10 real motherboard titles agree with them.

Wikipedia and retailers are secondary sources, so check manufacturer pages for anything critical.

## Updating the catalogue

1. Take values from the manufacturer's product page (Intel ARK, AMD, NVIDIA), not retailers.
2. Key entries by the normalized name `ModelResolver` produces, for example `RTX 4070 TI SUPER`.
3. Bump `catalogueVersion` and add resolver tests for any name that could be confused with an existing model.
4. Check the catalogue when new CPU or GPU generations launch.

A model missing from the catalogue is not an error: socket rules still apply, and power checks report `unknown`.

## Not covered yet

- **Clearance data is sparse.** Titles rarely state GPU length, case clearance or cooler height, so these checks usually report `unknown`. A per-product source would fix this.
- **RAM capacity and speed limits.** They vary per board and aren't in titles. Module count is checked only when both listings state it.
- **Radiator fit** for liquid coolers.
- **CPU support on older boards**, such as a BIOS update being needed; the app shows a reminder only.
