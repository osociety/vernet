# Vernet - QWEN Context Guide

## Project Overview

**Vernet** is a cross-platform network analyzer and monitoring tool built with Flutter. It provides comprehensive network diagnostics including device discovery, port scanning, DNS lookup, internet speed testing, and Wi-Fi information.

### Key Features
- Wi-Fi details (BSSID, MAC Address)
- Network device/host scanning
- Open port scanning for target IPs
- ISP details
- Internet speed test (speedtest.net)
- Ping and DNS tools

### Supported Platforms
- Android (primary - published on F-Droid & Google Play)
- iOS (emulator only)
- macOS
- Linux
- Windows
- Web

### Tech Stack
- **Framework:** Flutter (Dart SDK >=3.2.0 <4.0.0)
- **State Management:** Provider, flutter_bloc (BLoC pattern)
- **Dependency Injection:** get_it + injectable
- **Database:** Drift (SQLite)
- **Key Packages:** dart_ping, network_tools_flutter, speed_test_dart, flutter_map

---

## Repository Structure

```
vernet/
├── lib/                          # Main Flutter/Dart codebase
│   ├── main.dart                 # App entry point
│   ├── injection.dart            # DI configuration
│   ├── api/                      # API integrations
│   ├── database/                 # Drift database schemas
│   │   └── drift/                # Generated database code
│   ├── helper/                   # App helpers (settings, consent)
│   ├── models/                   # Data models
│   │   ├── drift/                # Database models
│   │   ├── device_in_the_network.dart
│   │   ├── port.dart
│   │   └── wifi_info.dart
│   ├── pages/                    # UI screens (feature-based)
│   │   ├── dns/                  # DNS lookup page
│   │   ├── host_scan_page/       # Network scanner
│   │   ├── isp_page/             # ISP info
│   │   ├── network_troubleshoot/
│   │   ├── ping_page/            # Ping tool
│   │   ├── port_scan_page/       # Port scanner
│   │   ├── home_page.dart
│   │   ├── settings_page.dart
│   │   └── location_consent_page.dart
│   ├── providers/                # State management
│   │   ├── dark_theme_provider.dart
│   │   └── internet_provider.dart
│   ├── repository/               # Data repositories
│   │   └── notification_service.dart
│   ├── services/                 # Business logic / networking
│   │   ├── impls/                # Service implementations
│   │   └── scanner_service.dart  # Network scanner abstraction
│   ├── ui/                       # UI components
│   ├── utils/                    # Helper utilities
│   │   ├── custom_axis_renderer.dart
│   │   └── device_util.dart
│   └── values/                   # Constants, keys, globals
├── test/                         # Unit & widget tests
├── integration_test/             # Integration tests
├── coverage/                     # Coverage reports
├── assets/                       # App assets (images, configs)
├── android/                      # Android platform code
├── ios/                          # iOS platform code
├── macos/                        # macOS platform code
├── linux/                        # Linux platform code
├── windows/                      # Windows platform code
├── web/                          # Web platform code
├── installers/                   # Distribution packages
├── fastlane/                     # CI/CD configuration
├── scripts/                      # Automation scripts
└── donation/                     # Donation-related assets
```

---

## Architecture

Vernet follows a **layered architecture**:

```
UI Layer (pages/, widgets/)
    ↓
Feature Layer (providers/)
    ↓
Service Layer (services/)
    ↓
Network/System Utilities (packages)
```

### Key Principles
1. **Separation of Concerns:** UI components must NOT perform network operations directly
2. **Service Abstraction:** All networking logic lives in `services/`
3. **Feature-based Organization:** Each network tool is a self-contained feature module
4. **Reusable Components:** Common UI elements in `widgets/` and `ui/`
5. **Immutable Data Models:** Data structures in `models/` are immutable where possible

### Data Flow Example
```
User taps Scan → HostScanPage → NetworkScannerService → Ping/ARP → List<Device>
```

---

## Building and Running

### Prerequisites
- Flutter SDK (compatible with Dart >=3.2.0 <4.0.0)
- Platform-specific tools (Android Studio, Xcode, etc.)

### Setup
```bash
# Install dependencies
flutter pub get

# Run code generation (for injectable, freezed, drift)
dart run build_runner build --delete-conflicting-outputs
```

### Running the App
```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d windows     # Windows
flutter run -d linux       # Linux
flutter run -d <device>    # Android/iOS
```

### Building for Production
```bash
flutter build apk          # Android
flutter build ios          # iOS
flutter build macos        # macOS
flutter build linux        # Linux
flutter build windows      # Windows
flutter build web          # Web
```

### Linux Note
Install `net-tools` package for `arp` command before running on Linux.

---

## Testing

### Run All Tests
```bash
# Unit & widget tests
flutter test

# Integration tests (desktop)
flutter test integration_test/app_test.dart -d macos
```

### Generate Coverage Report
```bash
# Run the coverage script
bash generate_coverage.sh
```

This script:
1. Runs unit tests with coverage
2. Runs integration tests with coverage
3. Combines both coverage reports
4. Excludes generated files (*.g.dart, drift files)
5. Generates HTML report at `coverage/html/index.html`

### Test Structure
- `test/` - Unit and widget tests organized by feature
- `integration_test/` - End-to-end integration tests
- `coverage/` - Coverage reports (unit.lcov.info, integration.lcov.info, lcov.info)

---

## Development Conventions

### Code Style
- Linting: Uses `lint` package (`package:lint/analysis_options.yaml`)
- Formatting: Standard Dart/Flutter formatting
- Generated files excluded from analysis: `*.g.dart`, `*.freezed.dart`, `*.config.dart`

### Key Rules
1. **UI Logic:** Keep in `pages/` or `widgets/`
2. **Network Logic:** Always in `services/`
3. **Data Models:** In `models/`, immutable where possible
4. **Utilities:** In `utils/`
5. **State Management:** Use Provider or BLoC, keep state local to features

### Dependency Injection
- Uses `get_it` with `injectable` for code generation
- Configuration in `lib/injection.dart`
- Environments: `prod`, `dev`, `test`, `demo`

### Important Files
- `ARCHITECTURE.md` - Detailed system architecture
- `AGENTS.md` - AI agent guidelines
- `pubspec.yaml` - Dependencies and Flutter config
- `analysis_options.yaml` - Linting rules
- `flutter_native_splash.yaml` - Splash screen config

---

## Adding a New Feature

When implementing a new network tool:

1. **Create Service** - `lib/services/new_feature_service.dart`
2. **Create Models** - `lib/models/new_feature_result.dart`
3. **Create UI Page** - `lib/pages/new_feature_page/`
4. **Connect UI to Service** - Use Provider/BLoC for state
5. **Add Tests** - `test/services/` and `test/pages/`

### Example Structure
```
lib/
├── pages/ping_page/
├── services/ping_service.dart
└── models/ping_result.dart
```

---

## Platform-Specific Notes

### Android
- Primary platform (F-Droid + Google Play)
- Permissions handled via `permission_handler`
- Fastlane configuration in `fastlane/`

### macOS
- Not notarized yet
- Manual installation: Copy to Applications, use "Open" with Cmd+click

### Linux
- Requires `net-tools` package for `arp` command

### Windows
- May require "Run anyway" on first launch
- Automatic permission requests

---

## Key Dependencies

### Core
- `flutter_bloc` - BLoC state management
- `provider` - Simple state management
- `get_it` + `injectable` - Dependency injection
- `drift` + `drift_flutter` - Local database

### Networking
- `dart_ping` - Ping functionality
- `network_tools_flutter` - Network utilities
- `speed_test_dart` - Speed testing (git dependency)
- `http` - HTTP requests

### UI
- `flutter_map` + `flutter_map_marker_cluster_plus` - Maps
- `syncfusion_flutter_gauges` - Gauges for speed test
- `auto_size_text` - Responsive text
- `percent_indicator` - Progress indicators

### Utilities
- `flutter_local_notifications` - Notifications
- `shared_preferences` - Local storage
- `package_info_plus` - App version info
- `url_launcher` - Open URLs

---

## Coverage & Quality

- Coverage reports generated in `coverage/`
- HTML report: `coverage/html/index.html`
- LCOV format: `coverage/lcov.info`
- Generated files excluded from coverage metrics

---

## Contact & Support

- **Email:** fs0c19ty@protonmail.com
- **GitHub:** https://github.com/git-elliot/vernet
- **F-Droid:** https://f-droid.org/packages/org.fsociety.vernet
- **Donations:** Liberapay, Ko-Fi

---

## Quick Reference

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Run codegen | `dart run build_runner build --delete-conflicting-outputs` |
| Run app | `flutter run` |
| Run tests | `flutter test` |
| Generate coverage | `bash generate_coverage.sh` |
| Build APK | `flutter build apk` |
| Clean build | `flutter clean` |

---

*Last updated: March 2026*
