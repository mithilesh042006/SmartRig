# SmartRig (Smart PC Builder) — Project Report

> **Status as of:** 22 October 2026
> **Repository:** `pc_buildere` · branch `main` · single commit `8e4ecf0 init` (2 Feb 2026)
> **Version:** `1.0.0+1`
> **Stage:** Working MVP / prototype. Core building, product search, performance estimation, saved builds and a community feed work end to end. Several features in the original design docs are not built yet, and the app is not production-ready (see [§11 Known Issues](#11-known-issues--technical-debt) and [§12 Security](#12-security-review)).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Technology Stack](#2-technology-stack)
3. [External APIs & Services](#3-external-apis--services)
4. [Architecture](#4-architecture)
5. [Project Structure](#5-project-structure)
6. [Features (Implemented)](#6-features-implemented)
7. [Screens & User Flow](#7-screens--user-flow)
8. [Data Model & Firestore Schema](#8-data-model--firestore-schema)
9. [Performance Prediction Engine](#9-performance-prediction-engine)
10. [Planned vs. Implemented](#10-planned-vs-implemented)
11. [Known Issues & Technical Debt](#11-known-issues--technical-debt)
12. [Security Review](#12-security-review)
13. [Code Quality & Testing](#13-code-quality--testing)
14. [Build & Run](#14-build--run)
15. [Recommended Next Steps](#15-recommended-next-steps)

---

## 1. Overview

**SmartRig** (internally *Smart PC Builder & Performance Predictor*, package `pc_buildere`) is a cross-platform Flutter app that lets users build a custom PC virtually:

- Pick each of the 8 components (CPU, GPU, motherboard, RAM, storage, PSU, case, cooling) from **live Amazon listings**
- See a **running total price**
- Get **estimated performance**: CPU/GPU/system scores, FPS for 5 popular games at 1080p/1440p/4K, power draw, recommended PSU wattage and bottleneck analysis
- View the build as a **3D model** that changes with the parts selected
- **Save** builds to the cloud (private or public), **compare** up to 3 saved builds side by side
- Browse a **community feed** of public builds with **likes and comments**
- Open any product on **Amazon** to buy it

**Target users:** first-time builders, gamers, content creators, budget buyers, PC enthusiasts.

**Backend approach:** no custom server. The app talks directly to **Firebase** (Auth + Firestore) and to the **RapidAPI "Real-Time Amazon Data"** API.

Design documents in the repo:
- [Smart_PC_Builder_Documentation.md](Smart_PC_Builder_Documentation.md) — product vision, feature scope, MVP
- [PC_Performance_Review.md](PC_Performance_Review.md) — performance-estimation formulas

---

## 2. Technology Stack

### 2.1 Core

| Layer | Technology |
|---|---|
| Framework | **Flutter** (stable channel, revision `f6ff1529`) |
| Language | **Dart** SDK `^3.10.4` (uses records, pattern-matching `switch` expressions) |
| UI | Material 3, custom light/dark themes, **Google Fonts – Inter** |
| State management | **Riverpod 3** (`Notifier`, `Provider`, `FutureProvider.family`, `StreamProvider`) |
| Auth | **Firebase Authentication** (email/password + Google Sign-In) |
| Database | **Cloud Firestore** (real-time streams) |
| Local storage | **SharedPreferences** (theme preference only) |
| Networking | `http` package |
| 3D rendering | `model_viewer_plus` (Google `<model-viewer>` web component in a WebView), `.glb` models |
| Charts | `fl_chart` (bar chart), `percent_indicator` (circular gauge) |

### 2.2 Dependencies ([pubspec.yaml](pubspec.yaml))

| Package | Version constraint | Used for |
|---|---|---|
| `flutter_riverpod` | ^3.0.3 | App-wide state, providers |
| `firebase_auth` | ^6.1.3 | Sign-in, registration, password reset |
| `cloud_firestore` | ^6.1.1 | Saved builds, public builds, likes, comments |
| `google_sign_in` | ^6.2.2 | Google OAuth sign-in |
| `firebase_core` | *(transitive — not declared, see §13)* | Firebase initialisation |
| `http` | ^1.6.0 | RapidAPI Amazon calls |
| `url_launcher` | ^6.3.2 | Open Amazon product pages |
| `model_viewer_plus` | ^1.8.1 | 3D build viewer |
| `fl_chart` | ^1.1.1 | FPS bar chart |
| `percent_indicator` | ^4.2.5 | System score gauge |
| `google_fonts` | ^6.3.3 | Inter font |
| `shared_preferences` | ^2.5.4 | Persist theme mode |
| `cupertino_icons` | ^1.0.8 | iOS icons |
| `flutter_launcher_icons` | ^0.14.4 | App icon generation *(listed under `dependencies`; belongs in `dev_dependencies`)* |
| `flutter_lints` (dev) | ^6.0.0 | Lint rules |

### 2.3 Platforms

Platform folders exist for **Android, iOS, Web, Windows, macOS, Linux**. Firebase is configured ([firebase_options.dart](lib/firebase_options.dart)) for **Android, iOS, macOS, Web and Windows**; Linux is not configured.

**Android is the main target:** app label `SmartRig`, `INTERNET` + `ACCESS_NETWORK_STATE` permissions, Java/Kotlin 17, `google-services` Gradle plugin, custom network security config.

---

## 3. External APIs & Services

### 3.1 RapidAPI — Real-Time Amazon Data

Implemented in [lib/services/amazon_api_service.dart](lib/services/amazon_api_service.dart).

| Item | Value |
|---|---|
| Host | `real-time-amazon-data.p.rapidapi.com` |
| Auth headers | `x-rapidapi-key`, `x-rapidapi-host` |
| Marketplace | `country=US` (prices in USD) |

**Endpoints used**

| Endpoint | Params | Purpose | Fields consumed |
|---|---|---|---|
| `GET /search` | `query`, `country`, `page=1` | Product list for a component slot (first **10** results) | `asin`, `product_title`, `product_price`, `product_photo`, `product_star_rating`, `product_num_ratings`, `product_url` |
| `GET /product-details` | `asin`, `country` | Product detail page | `product_title`, `product_description`, `product_photo(s)`, `product_price`, `product_star_rating`, `product_num_ratings`, `product_url`, `product_byline`, `about_product` |

**Query enforcement:** each component type has a default keyword string (e.g. CPU → `"Desktop CPU Processor"`, GPU → `"Graphics Card GPU"`, RAM → `"Desktop RAM DDR5"`). If the user's brand/model query doesn't already contain one of those keywords, they are appended so results stay on-topic.

**Error handling:** 15 s timeout on search; friendly messages for HTTP 403 (bad key / subscription), 429 (rate limit) and timeouts. Brand is guessed from the first word of the product title.

### 3.2 Firebase

| Item | Value |
|---|---|
| Project ID | `easybuild-3275c` |
| Auth domain | `easybuild-3275c.firebaseapp.com` |
| Storage bucket | `easybuild-3275c.firebasestorage.app` (configured, **not used** in code) |
| Services used | **Authentication**, **Cloud Firestore** |

**Auth methods** ([lib/services/auth_service.dart](lib/services/auth_service.dart)):
- Email + password sign-in and registration (with display name)
- Google Sign-In → Firebase credential
- Password-reset email
- Sign-out (Google and Firebase)
- Firebase error codes mapped to user-friendly messages

### 3.3 Amazon (web)

`url_launcher` opens the `product_url` returned by the API in an external browser/app ("Buy on Amazon"). No affiliate tag is added yet.

---

## 4. Architecture

```
┌───────────────────────────── Flutter App ─────────────────────────────┐
│                                                                       │
│  Screens (UI)  ──watch/read──►  Riverpod Providers  ──►  Services     │
│                                                                       │
│  • AuthWrapper                  • authStateProvider     • AuthService │
│  • MainNavigation (4 tabs)      • buildProvider         • AmazonApi-  │
│  • Builder / Selection          • componentsProvider      Service     │
│  • Product detail               • productDetailsProvider• Performance-│
│  • Review / Compare             • performanceResult-      Service     │
│  • Saved / Community / Profile    Provider              • SavedBuilds-│
│  • 3D Viewer                    • savedBuildsStream...    Service     │
│                                 • publicBuildsStream... │             │
│                                 • buildCommentsProvider │             │
│                                 • themeProvider         │             │
└─────────────────────────────────────────────────────────┼─────────────┘
                                                          │
              ┌───────────────────────────┬───────────────┴──────────┐
              ▼                           ▼                          ▼
     Firebase Auth               Cloud Firestore            RapidAPI Amazon
   (email, Google)        users/{uid}/builds,           /search, /product-details
                          public_builds/{id}/comments
```

**Key patterns**
- **Auth gate:** `AuthWrapper` in [main.dart](lib/main.dart) listens to `authStateChanges()` and shows `LoginScreen` or `MainNavigationScreen`.
- **In-memory build state:** `BuildNotifier` holds `Map<ComponentType, Component?>`. It is not saved locally; it is lost on app restart unless the user saves the build.
- **Derived state:** `performanceResultProvider` recalculates whenever the build changes.
- **Real-time sync:** saved builds, community builds and comments are Firestore `snapshots()` streams.
- **Tab persistence:** bottom navigation uses an `IndexedStack`, so each tab keeps its state.

---

## 5. Project Structure

```
pc_buildere/
├── lib/                                   (~6,200 lines of Dart)
│   ├── main.dart                     54   App entry, Firebase init, theme, AuthWrapper
│   ├── firebase_options.dart         88   FlutterFire generated config
│   ├── models/
│   │   └── component.dart            23   Component + ComponentType enum
│   ├── providers/
│   │   ├── build_provider.dart       86   Current build state, components search provider
│   │   └── theme_provider.dart      116   ThemeMode notifier + AppTheme (light/dark)
│   ├── services/
│   │   ├── amazon_api_service.dart  206   RapidAPI Amazon search & details
│   │   ├── auth_service.dart        147   Firebase/Google auth
│   │   ├── performance_service.dart 275   Scores, FPS, power, bottleneck
│   │   └── saved_builds_service.dart 339  Firestore CRUD, likes, comments, models
│   └── screens/
│       ├── main_navigation_screen.dart 349  Bottom nav + Home tab
│       ├── builder_screen.dart         258  8 component slots + total + actions
│       ├── component_selection_screen.dart 510  Brand→model chips + Amazon results
│       ├── product_detail_screen.dart  449  Details, gallery, Buy/Add actions
│       ├── review_build_screen.dart    637  Performance review + Save dialog
│       ├── compare_builds_screen.dart  345  Pick 2–3 builds, side-by-side
│       ├── saved_builds_screen.dart    240  User's builds: load / delete
│       ├── community_screen.dart       807  Public feed, likes, comments sheet
│       ├── build_3d_viewer_screen.dart 237  GLB model viewer
│       ├── profile_screen.dart         313  Account info, dark mode, sign out
│       ├── login_screen.dart           297  Email / Google sign-in, forgot password
│       ├── register_screen.dart        260  Account creation
│       └── home_screen.dart            133  ⚠ Legacy — not referenced anywhere
├── assets/                                (~74 MB)
│   ├── case*.glb  (8 files)               3D PC models by build stage
│   └── icon.png                           App icon source
├── test/widget_test.dart                  ⚠ Default counter template (stale)
├── android/ ios/ web/ windows/ macos/ linux/
├── firebase.json                          FlutterFire CLI config
├── Smart_PC_Builder_Documentation.md      Product spec
└── PC_Performance_Review.md               Performance-engine spec
```

---

## 6. Features (Implemented)

### 6.1 Authentication ✅
- Email/password login and registration (with display name)
- Google Sign-In
- Forgot password (reset email)
- Auto-routing based on auth state; sign-out with confirmation

### 6.2 Guided PC Builder ✅
- 8 slots: **CPU, Motherboard, GPU, RAM, Storage, PSU, Case, Cooling**
- Each slot shows the selected product name and price, or "Not Selected"
- Tap an empty slot → selection screen; tap a filled slot → product detail; edit icon → reselect
- Live **total estimate** in USD; "Clear Build" action
- "Review Build" (enabled once something is selected) and "View 3D Build" buttons

### 6.3 Component Selection (live Amazon data) ✅
- Two-step chip picker: **Brand → Model**, from a hard-coded catalogue per type, for example:
  - CPU: Intel (Core i3–i9, Xeon), AMD (Ryzen 3–9, Threadripper)
  - GPU: NVIDIA (RTX 3060–4090), AMD (RX 6700 XT–7900 XTX), Intel (Arc A580–A770)
  - Plus RAM (Corsair, G.Skill, Kingston, Crucial), motherboards (ASUS, MSI, Gigabyte, ASRock), storage, PSU, cases and coolers
- Choosing a model runs an Amazon search; with no selection, a default category search runs
- Result cards: image, title, brand, star rating, review count, price, quick "+" add
- Loading, error and retry states

### 6.4 Product Details ✅
- Full details from `/product-details`: image gallery, price, rating, reviews, brand, description, feature bullets
- **Buy on Amazon** (external link) and **Add to Build**

### 6.5 Performance Review ✅ (estimates)
- **Overall system score** gauge with tier label (Budget → Entry → Mid-Range → High-End → Enthusiast → Extreme)
- CPU and GPU score cards
- **FPS bar chart** for 5 games × 3 resolutions
- **Power draw** and **recommended PSU**
- **Bottleneck analysis** (CPU / GPU / Balanced, with %)
- Build summary list and a disclaimer that results are estimates
- Requires at least a CPU and GPU

### 6.6 Save Builds ✅
- Save dialog: name + **"Share with Community"** toggle (public/private)
- Stored in Firestore under the user; public builds are also copied to `public_builds`

### 6.7 Saved Builds ✅
- Real-time list of the user's builds
- Tap to **load** a build back into the builder
- Delete with confirmation

### 6.8 Compare Builds ✅
- Select **2–3** saved builds
- Horizontally scrolling comparison cards: price, system/CPU/GPU scores, 1080p FPS (top 3 games), power, PSU, bottleneck, component list

### 6.9 Community ✅
- Real-time feed of public builds (author, price, component chips, like count)
- **Like / unlike**
- Details bottom sheet with full component list and a **comments thread** (add; authors can delete their own comments)

### 6.10 3D Build Viewer ✅
- Interactive 3D model (rotate, zoom, auto-rotate) using `model_viewer_plus`
- Needs a **case** to be selected; the model shown depends on the parts selected:

| Condition (checked in order) | Model |
|---|---|
| Cooling selected | `case_cooling.glb` |
| GPU + RAM | `case_motherboard_gpu_ram.glb` |
| GPU | `case_motherboard_gpu.glb` |
| RAM | `case_motherboard_ram.glb` |
| CPU | `case_motherboard_cpu.glb` |
| Motherboard | `case_motherboard.glb` |
| PSU | `case_powersource.glb` |
| Case only | `case.glb` |

- Status chips for which parts are present, plus a build info dialog

### 6.11 Home Dashboard ✅
- Stats: total / public / private build counts
- "Start New Build" call to action
- Quick actions: **Compare** and **Popular** (community)

### 6.12 Profile & Theming ✅
- Email, display name, account created date, last sign-in
- **Dark mode toggle**, saved with SharedPreferences (defaults to the system theme)
- Material 3 themes: light (primary `#6200EE`) and dark (primary `#BB86FC`), Inter font

---

## 7. Screens & User Flow

```
Launch → Firebase.initializeApp → AuthWrapper
   ├─ signed out → LoginScreen ──► RegisterScreen
   └─ signed in  → MainNavigationScreen (bottom nav)
         ├─ [Home]    stats · Start New Build · Compare · Popular(Community)
         ├─ [Build]   BuilderScreen
         │               ├─ slot → ComponentSelectionScreen → ProductDetailScreenWithActions
         │               │                                     (Buy on Amazon / Add to Build)
         │               ├─ filled slot → ProductDetailScreen
         │               ├─ Review Build → ReviewBuildScreen → Save dialog (public/private)
         │               └─ View 3D Build → Build3DViewerScreen
         ├─ [Saved]   SavedBuildsScreen (load / delete)
         └─ [Profile] ProfileScreen (dark mode / sign out)
```

---

## 8. Data Model & Firestore Schema

### 8.1 Dart models

```dart
enum ComponentType { cpu, gpu, ram, motherboard, storage, psu, pcCase, cooling }

class Component {            // lib/models/component.dart
  String id;                 // Amazon ASIN
  String name, brand;
  ComponentType type;
  double price;              // USD
  String? imageUrl;
  Map<String, dynamic> specs; // Rating, Reviews, ProductUrl
}

class SavedBuild { id, name, components: Map<ComponentType, Component>,
                   totalPrice, createdAt, userId, isPublic, authorName,
                   likesCount, likedBy: List<String> }

class BuildComment { id, buildId, userId, userName, text, createdAt }
```

### 8.2 Firestore collections

```
users/{uid}/builds/{buildId}          ← private copy of every saved build
public_builds/{buildId}               ← duplicate of builds saved as public
public_builds/{buildId}/comments/{commentId}
```

**Build document**
```json
{
  "id": "auto-id",
  "name": "Gaming Beast",
  "components": {
    "0": { "id": "B0...", "name": "...", "brand": "...", "type": 0,
           "price": 299.99, "imageUrl": "...",
           "specs": { "Rating": "4.7", "Reviews": "1234", "ProductUrl": "..." } }
  },
  "totalPrice": 1499.95,
  "createdAt": "<Timestamp>",
  "userId": "<uid>",
  "isPublic": true,
  "authorName": "Jane",
  "likesCount": 3,
  "likedBy": ["uid1", "uid2", "uid3"]
}
```
Component keys are the `ComponentType` **enum index** as a string, so **reordering the enum would corrupt saved data**.

**Comment document**: `{ id, buildId, userId, userName, text, createdAt }`

> The spec doc lists `cpu_benchmarks`, `gpu_benchmarks` and `games` collections. These **do not exist**; benchmark data is hard-coded in `PerformanceService`.

---

## 9. Performance Prediction Engine

[lib/services/performance_service.dart](lib/services/performance_service.dart) is a local, rule-based estimator. It follows [PC_Performance_Review.md](PC_Performance_Review.md), except that scores come from **substring matching on product titles** instead of a benchmark database.

| Metric | Formula |
|---|---|
| CPU score | First matching key in the CPU map (Intel 28k, AMD 32k, Core 25k, Ryzen 30k, i9 35k, i7 28k, i5 20k, i3 12k); default 15k |
| GPU score | First matching key (RTX 4090 40k … RTX 3060 17k, RX 7900 32k … RX 6800 23k, GeForce 18k, Radeon/NVIDIA 20k, AMD 18k); default 15k |
| System score | `0.4 × CPU + 0.6 × GPU` |
| CPU bottleneck factor | `clamp(CPU / GPU, 0.7, 1.0)` |
| FPS @1080p | `baseFps1080 × (GPU / 25,000) × factor`, clamped 10–300 |
| FPS @1440p / 4K | `1080p × 0.70` (cap 200) / `× 0.45` (cap 120) |
| Power | `CPU TDP + GPU TDP + 50 W` (defaults 65 W / 200 W) |
| Recommended PSU | `power × 1.4` |
| Bottleneck | CPU if `CPU < 0.75 × GPU`; GPU if `GPU < 0.75 × CPU`; otherwise Balanced. % = `(1 − weaker/stronger) × 100` |

**Game profiles:** Cyberpunk 2077 (60), Call of Duty: Warzone (90), Fortnite (144), Red Dead Redemption 2 (55), Valorant (200). The `gpuScaling`/`cpuScaling` fields are defined but **not used** in the calculation.

**Reference baselines:** GPU 25,000 (≈ RTX 3080), CPU 30,000 (≈ i9-12900K; unused).

---

## 10. Planned vs. Implemented

Compared with [Smart_PC_Builder_Documentation.md](Smart_PC_Builder_Documentation.md):

| Planned feature | Status |
|---|---|
| Guided step-by-step builder (8 parts) | ✅ Done |
| Live product listings with purchase links | ✅ Done (Amazon US only) |
| Total cost calculation | ✅ Done |
| Performance prediction (FPS, power, bottleneck) | ✅ Done (heuristic) |
| Firebase Auth + saved builds in Firestore | ✅ Done |
| Community builds | ✅ Done (planned as a *future* enhancement, delivered early) |
| Build comparison | ✅ Done (not in the original spec) |
| 3D build visualisation | ✅ Done (not in the original spec) |
| **Compatibility validation engine** (socket, size, power, cooling) | ❌ Not started |
| Filters by price / brand / use case | ⚠️ Brand + model chips only; no price or use-case filters |
| Price comparison across multiple stores | ❌ Amazon only |
| Affiliate links | ❌ Not implemented |
| PDF export / share | ❌ Not implemented |
| Firebase Storage | ❌ Configured, unused |
| Benchmark data in Firestore | ❌ Hard-coded maps |
| Optimisation suggestions | ❌ Not implemented (bottleneck shown only) |
| ML-based prediction, backend services | ❌ Future |

---

## 11. Known Issues & Technical Debt

### Functional bugs

1. **CPU score lookup almost always uses the brand value.** The CPU map is iterated in insertion order and `Intel` / `AMD` come first. Amazon titles nearly always include the brand, so an "Intel Core **i3**" gets 28,000 (same as i7) and every AMD CPU gets 32,000. The tier keys (`i3`–`i9`, `Ryzen`) are effectively unreachable. Generic GPU keys (`GeForce`, `NVIDIA`) have the same problem for models missing from the map (e.g. RTX 4060, Intel Arc).
2. **Deleting a public build from "Saved" leaves it in the community feed.** [saved_builds_screen.dart:200](lib/screens/saved_builds_screen.dart#L200) calls `deleteBuild(build.id)` without `isPublic: build.isPublic`, so the `public_builds` copy is orphaned.
3. **Likes are not atomic.** `toggleLike` reads the document, then writes the whole `likedBy` list. Two users liking at the same time can overwrite each other. Should use a transaction or `FieldValue.arrayUnion/arrayRemove` + `FieldValue.increment`.
4. **FPS chart clipping:** the chart's `maxY` is 200, but 1080p FPS can reach 300 (e.g. Valorant on a high-end GPU).
5. **Current build is lost on restart.** Builder state is in-memory only.
6. **No compatibility checks.** A user can combine an AMD CPU with an Intel motherboard, DDR4 with a DDR5 board, or an undersized PSU without a warning.

### Code / maintenance debt

- [home_screen.dart](lib/screens/home_screen.dart) is dead code (replaced by `_HomeTab` in `main_navigation_screen.dart`).
- `_searchQueries`, `setSearchQuery` and `getCurrentQuery` in [build_provider.dart](lib/providers/build_provider.dart) are unused.
- `_sendPasswordReset` in [profile_screen.dart](lib/screens/profile_screen.dart) is unused (its UI is commented out).
- Bottom navigation bar colour is hard-coded dark (`#1E1E1E`) even in light theme.
- Component icon/label `switch` helpers are duplicated across several screens.
- Product-detail requests have no timeout (search uses 15 s).
- **3D assets total ~74 MB** and include byte-identical duplicates (`case_motherboard.glb` = `case_motherboard_cpu.glb`; `case_cooling.glb` = `case_powersource.glb`). This inflates app size by ~20 MB, and the "CPU" and "PSU" stages show no visual change.
- Placeholder metadata: `description: "A new Flutter project."`, default README, iOS display name `Pc Buildere`, Android `applicationId com.example.pc_buildere`.
- Android release builds are **signed with the debug key**.
- Prices are in USD from the US marketplace only; there is no currency or region setting.

---

## 12. Security Review

| Severity | Issue | Location | Recommendation |
|---|---|---|---|
| 🔴 High | **RapidAPI key hard-coded in source and committed to git** | [amazon_api_service.dart:37](lib/services/amazon_api_service.dart#L37) | Rotate the key now. Move calls behind a server-side proxy (e.g. Cloud Function) so the key never ships in the app. `--dart-define` is better than source but can still be extracted from the binary. |
| 🔴 High | **No Firestore security rules in the repo** (no `firestore.rules`) | project root | Write and deploy rules: users may only read/write `users/{own uid}/**`; `public_builds` writable only by `userId == auth.uid`; likes limited to `likedBy`/`likesCount`; comments deletable only by their author. Without rules, any client can edit or delete anyone's public build. |
| 🟠 Medium | **Cleartext (HTTP) traffic allowed globally** | `AndroidManifest.xml` (`usesCleartextTraffic="true"`), `network_security_config.xml` | All endpoints are HTTPS. Remove the cleartext permission. |
| 🟠 Medium | Comment deletion is only checked in the UI | `deleteComment` | Enforce in Firestore rules. |
| 🟢 Low | Firebase API keys in `firebase_options.dart` / `google-services.json` | — | Normal for Firebase client apps, but only safe with proper rules plus App Check and API-key restrictions in Google Cloud Console. |
| 🟢 Low | Release builds use debug signing | `android/app/build.gradle.kts` | Create a release keystore before distributing. |

---

## 13. Code Quality & Testing

**`flutter analyze`** (run 22 Oct 2026): **15 issues, no errors**
- 1 warning: unused `_sendPasswordReset` (profile_screen.dart)
- `depend_on_referenced_packages`: `firebase_core` is imported in `main.dart` but not declared in `pubspec.yaml` (it only works because other Firebase packages pull it in). **Add it explicitly.**
- Deprecations: `ColorScheme.background`, `Color.withOpacity`, `Switch.activeColor`
- Style: `(_, __, ___)` → `(_, _, _)` (Dart 3.7+ wildcards)

**Dependency freshness:** `pub get` reports ~80 packages with newer versions outside current constraints (e.g. `google_sign_in` 7.x has a breaking API change).

**Tests:** ❌ None useful. [test/widget_test.dart](test/widget_test.dart) is the default Flutter counter test. It would fail because the app has no counter and needs Firebase initialisation. There are no unit tests for `PerformanceService`, which is the logic that would benefit most from them.

**CI/CD:** none configured.

---

## 14. Build & Run

**Prerequisites:** Flutter (stable, Dart ≥ 3.10.4), Android SDK / Xcode, a Firebase project with Email/Password and Google sign-in enabled, and a RapidAPI subscription to *Real-Time Amazon Data*.

```bash
flutter pub get
flutter run                 # Android emulator / device (primary target)
flutter run -d chrome       # Web
flutter build apk --release # (currently debug-signed)
dart run flutter_launcher_icons   # regenerate app icons from assets/icon.png
```

**Google Sign-In on Android** needs the debug/release **SHA-1/SHA-256** fingerprints registered in the Firebase console, and an updated `google-services.json`.

**Reconfigure Firebase:** `flutterfire configure` (regenerates `firebase_options.dart` and `firebase.json`).

---

## 15. Recommended Next Steps

**Priority 1 — must-fix before any release**
1. Rotate the RapidAPI key and move Amazon calls behind a backend proxy
2. Add and deploy Firestore security rules
3. Fix public-build deletion (pass `isPublic`) and make likes atomic
4. Fix CPU/GPU score matching (most-specific key first, e.g. sort keys by length or use ordered regex rules)
5. Remove the cleartext-traffic allowance; set up release signing and a real `applicationId`

**Priority 2 — core product gaps**
6. **Compatibility engine:** CPU socket ↔ motherboard, RAM generation ↔ board, PSU wattage ↔ recommended, GPU length / cooler height ↔ case. This is the main missing MVP feature.
7. Save the in-progress build locally (SharedPreferences / Hive)
8. Move benchmark and game data to Firestore (as in the spec) so it can be updated without a release
9. Price/use-case filters; region and currency selection

**Priority 3 — polish & growth**
10. Affiliate tags on Amazon links (monetisation per spec)
11. Share/export builds (PDF or deep link)
12. Remove duplicate GLB assets and add real CPU/PSU stage models
13. Remove dead code, fix analyzer warnings, declare `firebase_core`
14. Unit tests for `PerformanceService` and widget tests with Firebase mocks; add CI (GitHub Actions: analyze + test)
15. Update README, app name and description
