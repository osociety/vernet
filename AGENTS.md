# AI Agent Guidelines for Vernet

This document provides guidance for AI coding agents working on the
Vernet repository. The goal is to help agents understand how to safely
modify the project and where to place new functionality.

------------------------------------------------------------------------

# Project Overview

Vernet is a cross-platform network diagnostics application built with
Flutter.

Supported platforms: - Android - iOS (coming soon) - Linux - macOS - Windows

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

# Agent Tooling

Several tool ecosystems touch this repository and no agent has all of
them. Apply what is available to you and ignore the rest. Never claim a
check ran when the tool for it was missing.

## Repository guidance

Read these before a structural change. They are the source of truth and
are deliberately not duplicated here.

-   `.github/copilot-instructions.md` — 100 ranked rules covering
    workflow and scope, Flutter architecture, error and dependency
    handling, testing, verification, and reporting. Written for Copilot
    but applicable to every agent.
-   `.github/agents/` — `project-task`, `issue-fixer` and `test-repair`
    agent definitions that wire those rules to the skills below.
-   `ARCHITECTURE.md` — system design.

## Project skills

`.github/skills/` holds eight Copilot-format skills. `.qoder/skills/`
holds two deep Qoder references plus a thin pointer to each Copilot skill,
so Qoder agents can invoke them without the procedure being copied twice.

Start from `project-task` when the right specialist is unclear. The
specialists are `github-issue-implementation`, `flutter-feature-iteration`,
`flutter-test-repair`, `github-actions-repository-workflows`,
`android-fastlane-release`, `firebase-hosting-config` and `close-chat`.
The Qoder-only references are `vernet-testing` and
`vernet-feature-scaffold`.

Edit `.github/skills/` for procedure changes and keep the `.qoder/skills/`
pointers thin, otherwise the two ecosystems drift apart.

Skills carry more detail than this section. Where they overlap, the skill
wins inside its own domain.

## Cross-agent MCP setup

The same tooling is wired into every agent that can read a project config,
so a task can move between IDEs mid-flight without losing context.

-   `.agents/mcp-servers.json` is the canonical MCP manifest. It is
    deliberately path-free: it names binaries and candidate locations, not
    resolved paths.
-   `node .agents/sync.mjs` generates each agent's config from it and
    mirrors `.qoder/skills/` into that agent's project skills root.
    `node .agents/sync.mjs --check` reports drift and exits non-zero.
-   Targets are Antigravity, Claude Code, VS Code/Copilot, Gemini CLI,
    Codex and Cursor. Qoder holds its MCP servers in app storage rather
    than a repo file, so nothing is generated for it.
-   Every generated file is gitignored, because it embeds absolute binary
    paths resolved on this machine. The manifest and the script are the
    tracked source of truth.

To add or change a server, edit the manifest and re-run the sync. Never
hand-edit a generated config — the next sync overwrites it.

Two caveats the script cannot paper over. The GitHub server needs per-app
authentication; agents that cannot do dynamic client registration read a
token from the environment variable named in the manifest, and no secret is
ever written to a file. And `codex mcp add` rewrites `~/.codex/config.toml`
wholesale, so comments and key order there do not survive a sync.

## Session start

If serena is available, activate it before the first code navigation or
edit: call `initial_instructions`, then `activate_project` with this
repository. Serena answers nothing until both succeed. If it is
unavailable or activation fails, fall back to grep and say so.

## Code navigation

`graphify-out/graph.json` is a live knowledge graph of the repository,
rebuilt automatically when branches change. It is gitignored and local to
each machine, so use it only when it exists.

-   Architecture, dependency and "where should this live" questions:
    `graphify query "<question>"`, or `graphify path A B` for
    relationships. Cheapest first move for anything broad, when
    available.
-   Symbol structure inside one file: serena `get_symbols_overview` and
    `find_symbol`. Graphify seeds on name matches and truncates, so it is
    weaker for "which widget renders what" inside a large file.
-   Files over roughly 300 lines: use serena when available, otherwise
    read the whole file. Do not grep it in slices — slicing a large file
    misses branches, especially conditional widget trees.
-   Callers, subclasses, implementations: serena
    `find_referencing_symbols` and `find_implementations`.
-   Editing inside a single symbol: serena `replace_symbol_body`.
-   A known symbol in a known file: grep directly. Indexing is wasted on
    a single lookup.

## Dart and Flutter diagnostics

When the dart MCP is available, prefer it; otherwise use the equivalent
`flutter` command and say which you ran.

-   Analysis of changed files: dart MCP `analyze_files`, else
    `flutter analyze`.
-   Runtime exceptions and widget-tree questions: dart MCP
    `get_runtime_errors` and `widget_inspector`.
-   Layout bugs across phone (390px) and desktop widths are measured, not
    inferred from source alone.

## Large command output

-   Redirect verbose output — CI logs, full test runs — to a file under
    `/tmp` and grep it. Never pull a whole log into context, and never
    pipe a test run through `tail` when you need its exit code.
-   headroom `headroom_compress`, when available, is only for content
    that must be reasoned over as a whole and cannot be reduced by grep.
-   rtk `run_command`, when available, is for high-volume `git`, `grep`,
    `find` and `ls` output.

## Repository knowledge

Qoder agents: call `SearchKnowledge` before exploring a module. Entries
cover architecture, conventions and setup commands, and are cheaper than
rediscovering the same structure each session.

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