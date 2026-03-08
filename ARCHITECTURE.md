# Vernet Architecture Guide

## Project Overview

Vernet is a cross-platform network analysis application built with
Flutter. The application provides network utilities including device
discovery, port scanning, DNS lookup, and internet speed testing.

The application targets:

-   Android
-   iOS
-   Linux
-   macOS
-   Windows
-   Web

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
integration_test/ ├── installers/ └── pubspec.yaml

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

flutter build apk flutter build ios flutter build macos flutter build
linux flutter build windows flutter build web

Packaging scripts are located in:

installers/

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
