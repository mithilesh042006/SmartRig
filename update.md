# SmartRig — Development Roadmap & Progress Tracker

> **Baseline report:** 22 October 2026
> **Project:** SmartRig — Smart PC Builder & Performance Predictor
> **Repository:** `pc_buildere`
> **Current baseline:** Working MVP / prototype
> **Purpose:** Track each development phase from planning through implementation and verification.

## How to use this file

- Keep this file at the project root as `update.md`.
- Treat the status of every task as **Not started** until implementation and verification are actually completed.
- Change a task to **In progress** when work begins and **Complete** only after the acceptance criteria are verified.
- Record the implementation date, relevant commit/PR, test results, and any remaining risks in the phase notes.
- Each task lives in exactly **one** phase. Other phases refer to it by ID instead of repeating it.
- Size estimates: **S** ≤ 1 day · **M** 2–4 days · **L** 1–2 weeks.
- This is a roadmap, not evidence that the listed work has already been implemented.

## Status legend

- `[ ] Not started`
- `[/] In progress`
- `[x] Complete — implementation and verification finished`

---

## Current Baseline — Reported as of 22 October 2026

### Implemented in the reported MVP

- [x] Flutter/Dart application with Riverpod 3 state management.
- [x] Firebase Authentication: email/password, Google Sign-In, password reset, sign-out.
- [x] Guided builder with eight component slots: CPU, motherboard, GPU, RAM, storage, PSU, case, and cooling.
- [x] Amazon product search and product details through RapidAPI; product links open externally.
- [x] Estimated system/CPU/GPU scores, game FPS estimates, power estimate, PSU recommendation, and bottleneck display.
- [x] 3D build viewer using GLB assets.
- [x] Save/load/delete builds using Firestore.
- [x] Compare two or three saved builds.
- [x] Community feed with public builds, likes, and comments.
- [x] Home dashboard, profile, and light/dark themes.

### Reported limitations at baseline

- [ ] Hardware compatibility validation is not implemented.
- [ ] Performance scoring relies on product-title substring matching and has known lookup bugs.
- [ ] In-progress builder state is not persisted across app restarts.
- [ ] Benchmark and game data are hard-coded in the performance service.
- [ ] Price/use-case filters and multi-store price comparison are not implemented.
- [ ] PDF export/build sharing and affiliate links are not implemented.
- [ ] Useful automated tests and CI/CD are not in place.
- [ ] Report flags a hard-coded RapidAPI key, missing Firestore rules file in the repository, cleartext-traffic allowance, and debug signing for Android release builds.
- [ ] No in-app account deletion; no reporting/blocking for public user content.
- [ ] Build components are keyed in Firestore by `ComponentType` enum index, so reordering the enum corrupts saved data.

---

# Phase 1a — Urgent Security and Data Integrity

**Priority:** P0 — do first (days, not weeks)
**Status:** In progress — everything is done except revoking the old RapidAPI key (1a.1, owner action)
**Goal:** Stop the credential leak, protect user data, and fix bugs that corrupt or orphan data.

## Work checklist

- [/] **1a.1** Rotate/revoke the RapidAPI key exposed in source control (it remains in git history, so revoking it is the only real fix). **S** — replacement key live on the Worker and verified 1 Nov 2026 (the key briefly used before it was also retired, because it was pasted in chat). *Owner: delete the old key in the RapidAPI dashboard; it still returned HTTP 200 when checked on 1 Nov 2026.*
- [x] **1a.2** Move Amazon API requests behind a server-side proxy (Cloudflare Worker, see decision log); remove the key from the Flutter app. **M**
  - [x] Worker routes `/search` and `/product-details` (`worker/`); key stored as a Worker secret; app calls them over HTTPS.
  - [x] Require an authenticated caller (Worker verifies the Firebase ID token against Google's public keys).
  - [x] Cache responses in D1 to reduce RapidAPI quota use.
  - [x] Deploy — `https://smartrig-proxy.smartrig-proxy.workers.dev`, 1 Nov 2026 (free plan, no card).
  - [x] Set the new key and confirm a real product search — verified through the live Worker on 1 Nov 2026 with a real Firebase ID token (temporary user, since deleted).
  - [x] Per-user rate limiting: 120 requests/hour per user, fixed window in the D1 `rate_limits` table.
- [x] **1a.3** Write, test, and deploy Firestore security rules. **M**
  - [x] Private builds readable/writable only by the owning user.
  - [x] Public builds created/edited/deleted only by their owner (`userId == request.auth.uid`).
  - [x] Non-owners may update **only** `likedBy` and `likesCount`, adding or removing only their own UID, with `likesCount == likedBy.size()`.
  - [x] Comments created only as the signed-in user; never edited; deleted by the comment author or by the build owner (needed so deleting a build can clear its comments).
  - [x] Rules tests run against the Firebase Emulator (`@firebase/rules-unit-testing`).
  - [x] Deploy rules (`firebase deploy --only firestore:rules`) — released to `easybuild-3275c` on 1 November 2026.
- [x] **1a.4** Fix public-build deletion so deleting a public saved build also removes its public-feed copy **and its comments** (batched, ≤ 500 writes per batch). **S**
- [x] **1a.5** Make like/unlike atomic: `FieldValue.arrayUnion/arrayRemove` + `FieldValue.increment`. No transaction: transforms apply server-side, so concurrent likes never conflict (a transaction exhausted its retries with 5 concurrent likers on the emulator). **S**
- [x] **1a.6** Quick fix for CPU/GPU score matching: evaluate the most specific keys before generic brand names. *(Full model-resolution rewrite is 2.C1.)* **S**
- [x] **1a.7** Minimal test setup, needed by the regression tests in this phase: `flutter test` unit tests for services; emulator-based rules tests. *(CI and broader coverage: Phase 4.)* **S**

## Acceptance criteria

- [ ] Old exposed RapidAPI credentials no longer work. *(owner: delete the old key; still active on 1 Nov 2026)*
- [x] Amazon API secrets are not shipped in the client app.
- [x] Firestore rules are deployed (`easybuild-3275c`, 1 Nov 2026) and pass emulator tests for authorized and unauthorized operations (34/34).
- [x] Deleting a public build removes it from the community feed.
- [x] Concurrent likes do not overwrite each other; non-owners cannot change any other field.
- [x] CPU/GPU matching tests pass for specific and generic product names.

**Completion notes**
- Completed on: code, verification and rules deploy 1 November 2026; Worker deployed and verified 1 November 2026; old key revocation pending.
- Commit/PR: not yet committed.
- Tests and evidence:
  - `flutter test`: pass, see Phase 2 notes for the current count (Worker client, performance matching, save/load, private vs public visibility, delete with comment cleanup incl. > 500 comments, likes incl. concurrent, comments).
  - `cd firestore_tests && npm test`: 34/34 pass on the Firestore Emulator, stable over 3 runs (incl. 8 concurrent likers and owner batch-deleting a build with others' comments).
  - `cd functions && npm test`: 12/12 pass (shared lookups in `functions/src/amazon.ts`: validation, key stays server-side, caching, error mapping).
  - `cd worker && npm test`: 12/12 pass (token verification, routing, error mapping, rate-limit and cache SQL run on SQLite).
  - Live Worker: preflight 204; missing and fake tokens 401; GET 405; real token returned Amazon results (4.8 s), repeat search served from the D1 cache (0.8 s), rate-limit counter recorded the requests.
- Remaining risks:
  - Until the old key is deleted, anyone with the git history can spend its quota.
  - To replace the key later: `cd worker && npx wrangler secret put RAPIDAPI_KEY`. To redeploy: `cd worker && npm run deploy`.
  - `functions/` is not deployed; it stays as the Blaze fallback and the Worker imports its `src/amazon.ts`, so don't delete it. Use `firebase deploy --only firestore:rules`, as a bare `firebase deploy` also tries Functions and fails on Spark.
  - On Windows, `firebase emulators:exec` leaves the emulator's Java process on port 8080 after the run; stop it before rerunning rules tests.

---

# Phase 1b — Stability and Release Hygiene

**Priority:** P0/P1 — immediately after 1a
**Status:** In progress — keystore and on-device checks left (owner will do these later)
**Goal:** Remove insecure defaults and clean up the baseline before feature work.

## Work checklist

- [/] **1b.1** Remove the global cleartext-traffic allowance; verify all requests use HTTPS. **S** — `usesCleartextTraffic` removed; the network security config now blocks cleartext except `127.0.0.1`, because `model_viewer_plus` serves GLB files to its WebView from an on-device `http://127.0.0.1` server (removing the config entirely would break the 3D viewer). No `http://` URLs remain in `lib/`. *Pending: on-device check.*
- [x] **1b.2** Choose the final Android `applicationId` and iOS bundle ID. **S** — `com.app.smartrig` on every platform, 1 Nov 2026. New Android and iOS apps registered in Firebase, the old debug SHA-1 carried over for Google Sign-In. The Dart package is still named `pc_buildere`; users never see it.
- [/] **1b.3** Create the Android release keystore and signing config; store and back up the credentials securely; stop distributing debug-signed builds. **S** — Gradle reads `android/key.properties` (gitignored; template in `android/key.properties.example`); release builds no longer fall back to the debug key. *Owner: create the keystore, then add its SHA-1 and SHA-256 to the `com.app.smartrig` Firebase app or Google Sign-In will fail on release builds.*
- [x] **1b.4** Remove byte-identical GLB duplicates (`case_motherboard_cpu.glb` = `case_motherboard.glb`, `case_powersource.glb` = `case_cooling.glb`) and point the viewer at the remaining files. *(New CPU/PSU stage models: 5.D1.)* **S** — saves 20 MB; every stage loads byte-identical content (same MD5) as before.
- [x] **1b.5** Declare `firebase_core` explicitly in `pubspec.yaml`; move `flutter_launcher_icons` to `dev_dependencies`. **S** — also removed the now-unused `http` dependency.
- [x] **1b.6** Resolve analyzer warnings and deprecated API usage (`ColorScheme.background`, `withOpacity`, `Switch.activeColor`). **S**
- [x] **1b.7** Remove dead code (`home_screen.dart`, unused search-query helpers in `build_provider.dart`, unused `_sendPasswordReset`) and deduplicate component icon/label helpers. **S** — helpers now live in `lib/models/component_type_ui.dart`.
- [x] **1b.8** Make the bottom navigation bar follow the active theme instead of a hard-coded dark colour. **S**
- [x] **1b.9** Regression tests for save/delete builds, public/private visibility, likes, and comments (uses the 1a.7 setup). **M** — `test/services/saved_builds_service_test.dart` (fake Firestore/Auth) + emulator rules tests.

## Acceptance criteria

- [/] No cleartext traffic is permitted (except on-device loopback for the 3D viewer); on-device HTTPS check pending.
- [/] Release builds use the intended application ID (done) and release signing key (keystore pending).
- [/] 3D viewer renders every stage correctly after asset cleanup — files are byte-identical; on-device check pending.
- [x] `flutter analyze` reports no warnings (no issues found).
- [x] Critical flows pass regression testing.

**Completion notes**
- Completed on: code 1 November 2026.
- Commit/PR: not yet committed.
- Tests and evidence: `flutter analyze` — no issues; all suites pass (counts under Phases 1a and 2).
- Remaining risks:
  - Android debug build verified 1 November 2026: `flutter build apk --debug` succeeds on JDK 17 (`flutter config --jdk-dir`) and NDK 28.2, and the APK reports package `com.app.smartrig`. A release build and running on a device are still unverified.
  - The old `com.example.pc_buildere` app is still registered in Firebase. Delete it once nothing uses it.
  - Google Sign-In on iOS was already unconfigured (no URL scheme in `Info.plist`, no `GoogleService-Info.plist`); out of scope until an iOS release is planned.

---

# Phase 2 — Hardware Compatibility and Performance Accuracy

**Priority:** P1 — core product
**Status:** Complete — 1 November 2026, with the data limits listed in the completion notes
**Goal:** Make build validation useful and make performance estimates more defensible.

## A. Specification data source — decide first (blocks B and C)

The Amazon API returns titles, prices and ratings only. It has no socket, memory type, dimensions or TDP. Compatibility checks cannot be built until a spec source exists.

- [x] **2.A1** Spike: choose the spec source. **M** — curated catalogue plus listing-title parsing; see `docs/hardware_specs.md` and the decision log.
- [x] **2.A2** Define a normalized specification schema per component type, with units, field provenance, and completeness/confidence. **M** — `lib/models/hardware_spec.dart`; per-field units and sources in `docs/hardware_specs.md`.
- [x] **2.A3** Decide how specs are collected, checked, updated, and versioned. **S** — `catalogueVersion` plus the process in `docs/hardware_specs.md`.
- [x] **2.A4** Handle missing, ambiguous, or conflicting specifications explicitly; never treat unknown compatibility as confirmed compatibility. **S**
- [x] **2.A5** Migrate saved-build storage away from enum-index keys to stable string keys (e.g. `"cpu"`, `"gpu"`), with a migration for existing documents. **M** — readers accept both formats; each owner's builds are rewritten when they next load saved builds. Verified on the Firestore Emulator.

## B. Model resolution (shared by compatibility and performance)

- [x] **2.B1** Build one model-resolution service that maps a product listing to a catalogue model (exact model identification, specific-first rules, generation-aware). **M** — `lib/services/model_resolver.dart`.
- [x] **2.B2** Unit tests across generations and similarly named models (e.g. RTX 4070 vs 4070 Ti vs 4070 Super; i5-12400 vs i5-13400). **S**

## C. Compatibility engine

- [x] **2.C1** Design a deterministic compatibility service separate from UI widgets. **M** — `lib/services/compatibility_service.dart`.
- [x] **2.C2** Validate CPU socket against motherboard socket.
- [x] **2.C3** Validate RAM generation and supported configuration against the motherboard. — generation, plus module count against slots when listings state them. Per-board capacity and speed limits are not in listings, so they are not checked.
- [x] **2.C4** Compare estimated system power demand against PSU capacity and required headroom.
- [x] **2.C5** Validate GPU length and CPU cooler height against case clearances when data is available. — read from titles when stated; titles rarely state them, so this usually reports unknown.
- [x] **2.C6** Check relevant cooling and physical-fit constraints. — motherboard/case size, cooler socket, cooler TDP rating against CPU peak.
- [x] **2.C7** Return structured results: compatible, incompatible, warning, or unknown, with a clear explanation for each conflict or warning.
- [x] **2.C8** Integrate validation into the builder and review screen. **M**
- [x] **2.C9** Unit tests for valid combinations, conflicts, and missing-data cases. **S**

## D. Performance prediction engine

- [x] **2.D1** Replace substring matching with 2.B1 model resolution (supersedes the 1a.6 quick fix). **S**
- [x] **2.D2** Define a structured CPU/GPU benchmark schema and versioned game profiles with benchmark sources. **M** — `lib/data/performance_data.dart`. An original editorial gaming index, because PassMark data needs a licence; see `docs/performance_estimates.md`.
- [x] **2.D3** Refactor the performance service into model resolution, benchmark lookup, estimation, and presentation layers. **M** — `ModelResolver`, `BenchmarkLookup`, `PerformanceEstimator`, `ScoreTier`.
- [x] **2.D4** Review CPU/GPU scaling and bottleneck formulas; either use the per-game `gpuScaling`/`cpuScaling` fields or remove them. **S** — now used: FPS is the lower of a GPU limit and a CPU limit.
- [x] **2.D5** Improve component power inputs and document PSU recommendation assumptions. **S** — review card and PSU check share `PowerEstimate`, using catalogue peak power; assumptions in `docs/hardware_specs.md`.
- [x] **2.D6** Fix FPS chart scaling so valid values are not clipped (`maxY` is 200 but 1080p FPS can reach 300). **S**
- [x] **2.D7** Document assumptions and uncertainty for FPS estimates. **S** — `docs/performance_estimates.md`; the review screen states them and flags parts with no data.
- [x] **2.D8** Unit tests for score lookup, formulas, edge cases, and missing benchmark records. **S**

## Acceptance criteria

- [x] Spec-source decision is recorded and the schema is documented.
- [x] Known incompatible configurations are identified before build review/save.
- [x] Unknown specifications produce an explicit unknown/warning state.
- [x] Model-resolution tests cover multiple generations and similarly named models.
- [x] Existing saved builds still load after the storage-key migration.
- [x] Performance calculations are reproducible and covered by automated tests.
- [x] The UI labels outputs as estimates and communicates meaningful limitations.

**Completion notes**
- Completed on: 1 November 2026.
- Commit/PR: not yet committed.
- Tests and evidence: `flutter analyze` no issues; `flutter test` 124/124 (resolver, compatibility, performance formulas, builder and review screens, key migration, 80 real Amazon titles in `test/fixtures/amazon_titles.json`); `cd firestore_tests && npm test` 34/34; `cd worker && npm test` 12/12.
- Remaining risks:
  - **FPS and scores are editorial estimates**, not measurements, and were not checked against real game benchmarks. Licensing measured data (PassMark quotes from about $1,000) would improve them; only the index tables would change.
  - **Catalogue power values** were compared with secondary sources, which corrected 4 entries. Some were not comparable; `docs/hardware_specs.md` lists them.
  - **Clearance checks usually report unknown**, because titles rarely state GPU length, case clearance or cooler height. RAM capacity and speed limits are not checked.
  - **Title parsing** covers 80 real titles from one day's top results. Unusual listings will more often report unknown, which is the safe failure.
  - Screens are covered by widget tests but have not been checked by eye on a device.

---

# Phase 3 — Data Reliability and Builder Experience

**Priority:** P1 — after core correctness
**Status:** Not started
**Goal:** Make building more resilient, improve data maintenance, and simplify component selection.

## Work checklist

- [ ] **3.1** Persist the in-progress build locally and restore it after app restart. **S**
- [ ] **3.2** Define how local draft state interacts with saved Firestore builds. **S**
- [ ] **3.3** Move benchmark/game data out of hard-coded maps into the data source chosen in 2.A1 (Firestore vs versioned static/API source). **M**
- [ ] **3.4** Add price-range filters. **S**
- [ ] **3.5** Add budget and use-case filters (gaming, productivity, content creation) where supported by data. **M**
- [ ] **3.6** Design region and currency settings; keep source marketplace and converted currency clear. **M**
- [ ] **3.7** Add consistent timeouts, retry policy, and user-facing errors to product-detail requests (search already has a 15 s timeout). **S**
- [ ] **3.8** Review product search query behaviour and empty/error states. **S**

## Acceptance criteria

- [ ] An unfinished build survives an app restart.
- [ ] Benchmark data can be updated without changing estimator code.
- [ ] Filters return relevant products and handle empty results.
- [ ] Price/currency presentation is unambiguous.
- [ ] Product requests fail gracefully within defined time limits.

**Completion notes**
- Completed on:
- Commit/PR:
- Tests and evidence:
- Remaining risks:

---

# Phase 4 — Testing, Release Readiness, and Store Compliance

**Priority:** P1 — before public distribution
**Status:** Not started
**Goal:** Establish repeatable quality checks and prepare a secure, compliant release.

## A. Testing and CI

- [x] **4.A1** Replace the stale default counter test with SmartRig-relevant tests. **S** — removed during Phase 1b (it failed); service tests replace it.
- [ ] **4.A2** Widget tests for key builder and review flows using Firebase fakes (setup from 1a.7). **M**
- [ ] **4.A3** Integration tests for sign-in, component selection, saving, loading, deleting, and build review. **M**
- [ ] **4.A4** GitHub Actions: `flutter analyze`, `flutter test`, and emulator-based rules tests. **S**
- [ ] **4.A5** Review dependency updates individually for breaking changes (e.g. `google_sign_in` 7.x). **M**

## B. Store compliance (required for Google Play)

- [ ] **4.B1** In-app **account deletion**: deletes the auth account, private builds, public-build copies, and the user's comments (or anonymizes them). Also provide a web deletion-request link for the store listing. **M**
- [ ] **4.B2** **Report and block** for public builds and comments (Play user-generated-content policy), with a basic moderation path to review reports. **M**
- [ ] **4.B3** Privacy policy and Data Safety disclosures matching actual data collection and third-party services (Firebase, Google Sign-In, RapidAPI/Amazon). **S**
- [ ] **4.B4** Update README, app description, display name, and platform metadata. **S**

## C. Production configuration

- [ ] **4.C1** Register release-key SHA-1/SHA-256 fingerprints in Firebase for Google Sign-In (needs 1b.2 and 1b.3). **S**
- [ ] **4.C2** Enable App Check and restrict Google Cloud API keys. **S**
- [ ] **4.C3** Verify deployed Firestore rules and Functions in the production project. **S**

## D. Release verification

- [ ] **4.D1** Test release builds on real devices and supported screen sizes. **M**
- [ ] **4.D2** Check startup, offline/error states, API limits, accessibility, and crash behaviour. **M**
- [ ] **4.D3** Confirm final app bundle/APK size is acceptable (GLB assets are ~74 MB before 1b.4). **S**

## Acceptance criteria

- [ ] Static analysis and automated tests pass in CI.
- [ ] Critical flows pass on a real Android device.
- [ ] Users can delete their account and all associated data from inside the app.
- [ ] Users can report and block public content.
- [ ] Firebase authentication and database access work with production configuration.
- [ ] No known critical security issue remains unresolved.
- [ ] Store metadata and privacy disclosures accurately describe the app.

**Completion notes**
- Completed on:
- Commit/PR:
- Test devices/build:
- Remaining risks:

---

# Phase 5 — Advanced Features and Growth

**Priority:** P2 — after a stable release
**Status:** Not started
**Goal:** Differentiate SmartRig with useful recommendations, sharing, and sustainable growth features.

## A. AI recommendations and optimization

- [ ] **5.A1** Define recommendation inputs: budget, use case, region, available products, and user preferences.
- [ ] **5.A2** Build recommendations on top of validated specifications and benchmark data.
- [ ] **5.A3** Suggest compatible alternatives within budget, explaining cost/performance trade-offs and the reason for each recommendation.
- [ ] **5.A4** Keep deterministic compatibility rules authoritative; AI must not override known incompatibilities.
- [ ] **5.A5** Evaluate prediction quality and recommendation usefulness before broad release.

## B. Sharing and export

- [ ] **5.B1** Design a shareable build format or deep link.
- [ ] **5.B2** PDF export with component list, prices, compatibility results, and performance estimates.
- [ ] **5.B3** Define public/private sharing controls and avoid leaking private build data.

## C. Monetization and catalogue expansion

- [ ] **5.C1** Evaluate affiliate-link integration and required disclosures.
- [ ] **5.C2** Evaluate additional product sources and multi-store price comparison; normalize products across stores before comparing.
- [ ] **5.C3** Define handling for stale prices, unavailable products, and region differences.

## D. Visualization and community

- [ ] **5.D1** Add real CPU and PSU 3D stages and improve existing component-stage models.
- [ ] **5.D2** Expand moderation tooling beyond the 4.B2 baseline as the community grows.
- [ ] **5.D3** Evaluate additional build discovery and sharing features based on user feedback.

## Acceptance criteria

- [ ] Recommendations use structured data and return compatible configurations.
- [ ] Sharing respects access permissions.
- [ ] Exported reports clearly distinguish estimates from guaranteed results.
- [ ] Affiliate and catalogue integrations meet applicable service terms and disclosure needs.
- [ ] New features have measurable acceptance criteria and appropriate tests.

**Completion notes**
- Completed on:
- Commit/PR:
- User feedback/metrics:
- Remaining risks:

---

# Cross-Phase Decision Log

Record architectural decisions here so future changes remain consistent.

| Decision | Current plan / question | Status |
|---|---|---|
| Client architecture | Flutter + Riverpod 3 | Existing |
| Authentication/database | Firebase Auth + Cloud Firestore | Existing |
| Amazon API proxy hosting | Cloudflare Worker (`worker/`) on the free plan, so Firebase can stay on Spark with no billing account. Key in a Worker secret. Replaces the 22 Oct choice of Cloud Functions, which needs Blaze; `functions/` remains as a fallback. | Chosen — 1 Nov 2026 |
| Proxy caching & quotas | Cache search/detail responses in Cloudflare D1 (`api_cache`) with a TTL, since the Cache API does not work on `workers.dev` URLs; per-user limit of 120 requests/hour (`rate_limits`). Tune once usage is known. | Chosen — 1 Nov 2026 |
| Like writes | `arrayUnion/arrayRemove` + `increment` without a transaction; rules enforce `likesCount == likedBy.size()`, so a stale double-like is rejected rather than corrupting data. | Chosen — 1 Nov 2026 |
| Comment cleanup | Client deletes a public build's comments in the same batch as the build; rules let the build owner delete comments on their build. Revisit as a server-side trigger for account deletion (4.B1). | Chosen — 1 Nov 2026 |
| Android cleartext | HTTPS only, except `127.0.0.1` for `model_viewer_plus`'s on-device GLB server. | Chosen — 1 Nov 2026 |
| Public build storage | Currently each public build is stored twice (`users/{uid}/builds` + `public_builds`), which lets copies drift. Options: single collection with `isPublic` flag, or keep copies and sync server-side. | To decide (before Phase 2) |
| Build component keys | Stable string keys; readers accept both formats, owners' builds migrate on load (2.A5). | Done — 1 Nov 2026 |
| Hardware specifications source | Curated catalogue (`lib/data/hardware_catalogue.dart`) plus listing-title parsing, derived on the device. Paid APIs and scraping rejected. See `docs/hardware_specs.md`. | Chosen — 1 Nov 2026 |
| Compatibility validation | Deterministic service with explicit unknown states. Shown in the builder and review; never blocks saving, because title-derived data can be wrong. | Chosen — 1 Nov 2026 |
| Performance benchmarks | Original editorial gaming index and versioned game profiles (`lib/data/performance_data.dart`). PassMark scores rejected unless licensed. | Chosen — 1 Nov 2026 |
| Draft persistence | Local structured persistence for unfinished builds | Planned |
| Testing | `flutter test` + Firestore Emulator rules tests from Phase 1a; GitHub Actions in Phase 4 | Planned |
| Application ID | `com.app.smartrig` on all platforms. | Chosen — 1 Nov 2026 |
| Visual design | Shared tokens and widgets (`lib/theme/`, `lib/widgets/`) with separate light and dark palettes ("Volt": lime and tangerine on ink and warm sand); WCAG AA contrast enforced by test. Space Grotesk and Inter load through `google_fonts` at runtime. | Chosen — 2 Nov 2026 |
| Public release | Release signing, security and store review | Planned |

## Progress Summary

Update these counts as tasks are completed and verified (top-level tasks only).

| Phase | Done / Total | Status |
|---|---|---|
| 1a — Urgent security and data integrity | 6 / 7 | In progress — delete the old RapidAPI key |
| 1b — Stability and release hygiene | 7 / 9 | In progress — keystore, device check left |
| 2 — Hardware compatibility and performance accuracy | 24 / 24 | Complete — see data limits in the completion notes |
| 3 — Data reliability and builder experience | 0 / 8 | Not started |
| 4 — Testing, release readiness, and store compliance | 1 / 15 | Not started (4.A1 done early) |
| 5 — Advanced features and growth | 0 / 14 | Not started |

> **Important:** The checkboxes in the baseline section document features reported as already implemented in the 22 October 2026 report. All future-work checkboxes are unchecked until verified. Do not mark a phase complete until its acceptance criteria are verified.
