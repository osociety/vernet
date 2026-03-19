# AI Agent Guidelines for Vernet

This document provides guidance for AI coding agents working on the
Vernet repository. The goal is to help agents understand how to safely
modify the project and where to place new functionality.

------------------------------------------------------------------------

# Project Overview

Vernet is a cross-platform network diagnostics application built with
Flutter.

Supported platforms: - Android - iOS - Linux - macOS - Windows - Web

The application provides tools such as: - Device discovery - Port
scanning - DNS lookup - Network diagnostics - Internet speed testing

All primary application logic resides in the `lib/` directory.
All coverage related files inside `coverage/` directory

------------------------------------------------------------------------

# Core Architecture

The project follows a layered architecture:

UI Layer ↓ Feature Screens ↓ Service Layer ↓ Network Utilities

Important rule: UI must never perform network operations directly. All
network logic must go through the service layer.

------------------------------------------------------------------------

# Repository Structure

lib/ ├── main.dart ├── pages/ ├── widgets/ ├── services/ ├── models/
├── utils/ ├── providers/ └── routing/

Directory purposes:

pages → UI pages for each tool\
widgets → reusable UI components\
services → networking logic\
models → data structures\
utils → helper functions\
providers → state management\
routing → navigation configuration

------------------------------------------------------------------------

# How to Implement Features

When adding a new network tool:

1.  Create UI screen in `lib/pages/`
2.  Create service in `lib/services/`
3.  Create data models in `lib/models/` if needed
4.  Connect UI to the service layer

Example structure:

lib/pages/ping_page/ lib/services/ping_service.dart
lib/models/ping_result.dart

------------------------------------------------------------------------

# UI Development Rules

UI components should:

-   remain stateless where possible
-   delegate logic to services
-   reuse components from `widgets/`

Avoid placing network or heavy logic inside widgets.

------------------------------------------------------------------------

# Networking Rules

Networking operations must live inside `services/`.

Examples:

lib/services/network_scanner/ lib/services/port_scanner/
lib/services/dns_tools/ lib/services/speedtest/

Services should:

-   return structured models
-   avoid UI dependencies
-   be reusable across screens

------------------------------------------------------------------------

# State Management

State should remain local to features.

Preferred approaches:

-   Provider
-   Riverpod
-   simple StatefulWidget state

Avoid global mutable state unless necessary.

------------------------------------------------------------------------

# Data Models

All structured data must live in `models/`.

Examples:

-   Device
-   PortResult
-   DnsResult
-   SpeedTestResult

Models should:

-   be immutable when possible
-   support JSON serialization if needed

------------------------------------------------------------------------

# Code Modification Guidelines

When modifying code:

UI change → modify `pages/` or `widgets/`\
Network feature → modify `services/`\
Data structure → modify `models/`\
Utility function → modify `utils/`

Never mix UI logic and network operations.

------------------------------------------------------------------------

# Platform Specific Code

Platform specific implementations exist in:

android/ ios/ linux/ macos/ windows/

Agents should avoid modifying these unless absolutely necessary.

Most functionality should be implemented in Flutter/Dart.

------------------------------------------------------------------------

# Testing Guidelines

Unit tests live in:

test/

Integration tests live in:

integration_test/

Coverage folder

coverage/

Combined unit test file

coverage/lcov.info

Agents adding new functionality should add tests when possible.

------------------------------------------------------------------------

# Dependency Management

Dependencies are defined in:

pubspec.yaml

When adding dependencies:

-   prefer lightweight packages
-   avoid redundant libraries
-   maintain cross-platform compatibility

------------------------------------------------------------------------

# Best Practices

Agents should:

-   reuse existing services
-   maintain separation of concerns
-   keep functions small and focused
-   prefer composition over duplication

------------------------------------------------------------------------

# Example Workflow

To implement a new feature:

1.  Create service for network logic
2.  Define model for results
3.  Create UI screen
4.  Connect screen to service
5.  Add widgets for display

------------------------------------------------------------------------

# Summary

The most important rules:

1.  UI in `pages/`
2.  Reusable components in `widgets/`
3.  Networking in `services/`
4.  Data structures in `models/`
5.  Helpers in `utils/`
6.  Coverage in `coverage/`

Maintaining this separation ensures the project remains maintainable and
scalable.


## Architecture Reference
Always read ARCHITECTURE.md before making structural changes.
Use it as the source of truth for system design.