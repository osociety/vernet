# Vernet Architecture Guide

## Project Overview

Vernet is a cross-platform network analysis application built with
Flutter. The application provides network utilities including device
discovery, port scanning, DNS lookup, and internet speed testing.

The application targets:

-   Android
-   iOS (coming soon)
-   Linux
-   macOS
-   Windows

All primary logic resides in the Flutter/Dart codebase inside `lib/`.

------------------------------------------------------------------------

# Architecture Style

The project follows a layered architecture commonly used in Flutter
applications.

Layers:

UI Layer ↓ Feature Layer ↓ Service Layer ↓ Network / System Utilities

Each layer depends only on the layer below it.

------------------------------------------------------------------------

# Repository Structure

root │ ├── android/ ├── ios/ ├── linux/ ├── macos/ ├── windows/ ├── web/

├── assets/

├── lib/ │ │ ├── main.dart │ │ │ ├── pages/ │ │ Feature screens for
each network tool │ │ │ ├── widgets/ │ │ Reusable UI components │ │ │
├── services/ │ │ Core networking functionality │ │ │ ├── models/ │ │
Data models used across the app │ │ │ ├── utils/ │ │ Helper functions
and utilities │ │ │ ├── providers/ │ │ Application state management │ │
│ └── routing/ │ Navigation configuration │ ├── test/ ├──
integration_test/ ├── scripts/ └── pubspec.yaml

------------------------------------------------------------------------

# Module Dependency Graph

pages ↓ widgets ↓ providers ↓ services ↓ utils ↓ models

Key rule:

UI components must not directly perform network operations. Networking
should always go through the `services` layer.

------------------------------------------------------------------------

# Feature Modules

Each network tool functions as a feature module.

Example feature structure:

lib/pages/host_scan_page/ lib/services/scanner_service.dart
lib/models/device.dart

Typical module responsibilities:

### Device Discovery

Detect devices on the local network.

Responsibilities:

-   subnet scanning
-   ping hosts
-   resolve device names
-   detect vendors

Service location:

lib/services/network_scanner/

------------------------------------------------------------------------

### Port Scanner

Scan TCP ports on a target host.

Responsibilities:

-   connection probing
-   open port detection
-   service identification

Service location:

lib/services/port_scanner/

------------------------------------------------------------------------

### DNS Tools

Network lookup utilities.

Responsibilities:

-   DNS resolution
-   reverse DNS
-   IP information

Service location:

lib/services/dns_tools/

------------------------------------------------------------------------

### Wake on LAN

Send a magic packet to power on a device that supports Wake-on-LAN.

Responsibilities:

-   MAC and broadcast address validation
-   magic packet sending
-   saved device list

Service location:

lib/services/wake_on_lan_service.dart

------------------------------------------------------------------------

### Speed Test

Internet performance measurement.

Responsibilities:

-   latency measurement
-   download test
-   upload test

Service location:

lib/services/speedtest/

------------------------------------------------------------------------

# UI Architecture

The UI is composed of Flutter widgets organized by feature screens.

Flow:

main.dart → Home screen → Feature screens → Widgets

Reusable components include:

-   cards
-   lists
-   network result tables
-   input forms

All reusable components are located in:

lib/widgets/

------------------------------------------------------------------------

# State Management

State is managed per feature screen.

Possible patterns:

-   Provider
-   simple stateful widgets
-   scoped state management

State objects should remain independent from networking logic.

------------------------------------------------------------------------

# Data Flow

Typical execution flow:

User action → UI screen → Provider / controller → Service layer →
Network utilities → Result returned to UI

Example:

Scan button → DeviceScannerScreen → NetworkScannerService → Ping / ARP
scan → List`<Device>`{=html}

------------------------------------------------------------------------

# Platform Integrations

Platform specific code exists in:

android/ ios/ linux/ macos/ windows/

These layers provide:

-   OS permissions
-   system networking commands
-   platform-specific capabilities

The Flutter layer interacts with these through plugins or platform
channels.

------------------------------------------------------------------------

# Testing Strategy

Two testing layers exist.

Unit Tests

test/

Integration Tests

integration_test/

Integration tests simulate full feature workflows.

Coverage folder

coverage/

Combined unit test file

coverage/lcov.info

------------------------------------------------------------------------

# Build and Distribution

The project supports building for multiple platforms using Flutter.

Example commands:

flutter build apk flutter build macos flutter build linux flutter build windows

Packaging scripts are located in:

scripts/installers/

## Build flavors

Android builds in three flavors (`dev`, `fdroid`, `store`). Only `store`
carries the proprietary SDKs, so the committed `pubspec.yaml` never
declares them and the ad-free builds stay F-Droid compliant:

-   `lib/values/build_flavor.dart` holds the const gates. A const
    comparison against `String.fromEnvironment` folds at compile time, so
    a flavor carries no dead branch in its AOT image.
-   `lib/store/` is the inert seam every call site uses. It compiles
    without an ad SDK and renders nothing.
-   `store_overlay/` holds the real AdMob and InAppReview
    implementations. `dart run scripts/build_store.dart` splices those
    files into `lib/store/`, adds the SDK dependencies to `pubspec.yaml`,
    builds the store bundle, then restores every touched file
    byte-for-byte. The overlay never reaches a commit.
-   Per-flavor manifest entries live in
    `android/app/src/<flavor>/AndroidManifest.xml`.

The release pipeline publishes from one build: `release-android` ships
the ad-free APKs, then builds the store bundle in the same job and
`publish-play-store` supplies it to Google Play, at the same stage as
`publish-snap` does for the Snap Store.

Windows follows the same shape: `release-windows` builds the x64 and ARM64
packages, `publish-windows` packs them into one `.msixbundle`, and
`publish-ms-store` hands that bundle to the live product through
`ms_store_release.yml`. `publish-ms-store-listing` then publishes the Store
listing through `ms_store_metadata.yml` — after the package, because
`msstore publish` rebuilds the draft from the last published submission and
so discards any listing text staged before it. Both legs share the
`ms-store-publish` concurrency group, and the Store CLI only updates a product
that is already live, which is why the first publication had to happen in
Partner Center.

The listing is assembled rather than stored. `metadata/store/<locale>/` holds
one directory per language — `title.txt`, `description.txt`, `features.txt`,
`keywords.txt`, `release_notes.txt`, and `short_description.txt` when that
field is written — and `dart run scripts/ms_store_listing.dart` overlays those
files onto a fresh `msstore submission get` capture. Screenshots, packages,
markets and hardware come from the Store because nothing in git owns them; the
prose comes from git because that is where a rewrite gets reviewed. The same
script enforces the Store's per-field limits, repairs the placeholder price a
free product is captured with, and reports each field it changes by size, so a
public CI log shows what moved without copying the listing into it.

An update replaces the whole submission, so a locale that git does not declare
is carried through from the capture rather than dropped, and a locale in git
that the product does not serve is refused until it is enabled in Partner
Center — Store listing > Add/remove languages — with `allow_new_locales` saying
that has happened. The workflow has three modes: `get` captures the live
submission and uploads a redacted copy, which is the cheapest way to read what
the Store actually serves; `stage` writes the overlay into the pending draft;
`update` stages and then commits it. A push to `metadata/store/**` on main only
ever stages, so the release pipeline — or a deliberate `mode=update` dispatch —
is what reaches shoppers. The checked-in `metadata/metadata.json` capture this
replaced went stale against the release that followed it, and a run publishing a
listing whose package set no longer matched was a rollback waiting to happen.

The Android integration workflow runs the whole suite once per flavor as a
matrix. `flutter test --flavor` injects the same define a build does, which is
the only route to the gated branches: `--dart-define=FLUTTER_APP_FLAVOR` is
rejected as a reserved tool name, so unit tests can never reach them. A suite
that reaches flavor-gated UI has to read the gate constants instead of assuming
one flavor — `fdroid` has no update tile, and `store` prepends a banner row to
the host, port and DNS lists.

------------------------------------------------------------------------

# Design Principles

The repository follows these principles:

1.  Feature-based UI organization
2.  Service abstraction for networking
3.  Reusable widgets
4.  Minimal platform-specific logic
5.  Cross-platform compatibility

------------------------------------------------------------------------

# Rules for Contributors and AI Agents

When modifying this repository:

UI components → screens/ or widgets/

Networking functionality → services/

Data structures → models/

Helper utilities → utils/

Avoid placing network logic inside UI code.

Always reuse existing services when implementing new network features.

------------------------------------------------------------------------

# Typical Modification Examples

Adding a new network tool:

1.  Create new screen in screens/
2.  Create service in services/
3.  Create models if necessary
4.  Connect UI to service

Fixing UI:

Modify widgets or screen components only.

Fixing network logic:

Modify service layer without touching UI where possible.
