---
name: vernet-feature-scaffold
description: Scaffold a new or modified Vernet feature across pages/widgets, bloc, getIt service, drift repository, and tests. Use when adding a network tool, screen, bloc event/state, injectable service, drift table/repository, DI registration, route, or mirrored unit/widget tests in this Flutter repo; also use when deciding where a change belongs under the AGENTS.md/ARCHITECTURE.md layers.
---

# Vernet Feature Scaffold

## Overview

Build Vernet features in the repository's existing layered shape:

```text
pages / widgets  ->  bloc  ->  injectable service  ->  drift repository  ->  model
```

The UI layer must never perform network I/O. Keep every change in the layer that
owns it, mirror new tests under `test/`, and preserve the existing conventions
instead of introducing parallel patterns.

## Read first

1. Read `ARCHITECTURE.md` before any structural change.
2. Read `AGENTS.md` for the layer rules and testing locations.
3. Copy the closest existing feature rather than inventing structure:
   - Full bloc + drift + history flow: `lib/pages/host_scan_page/`
   - Bloc-only flow: `lib/pages/ping_page/`
   - Simple one-shot tool: `lib/pages/wake_on_lan_page/`

## Follow the actual repository layout

`AGENTS.md` names `lib/widgets/` and `lib/routing/`, but this repository does
not contain them. Follow the real layout:

| Concern | Location |
| --- | --- |
| Feature page | `lib/pages/<feature>/<feature>_page.dart` |
| Feature widgets | `lib/pages/<feature>/widgets/` |
| Bloc, events, state | `lib/pages/<feature>/<feature>_bloc/` |
| Shared and adaptive UI | `lib/ui/`, `lib/ui/adaptive/` |
| Network/platform services | `lib/services/`, implementations in `lib/services/impls/` |
| Drift repositories | `lib/repository/drift/` |
| Domain and drift models | `lib/models/`, `lib/models/drift/` |
| Database | `lib/database/drift/drift_database.dart` |
| Strings and keys | `lib/values/strings.dart`, `lib/values/keys.dart` |
| Routes | `lib/main.dart` (`onGenerateRoute`) |
| Tests | `test/` mirroring `lib/` paths |

Do not create empty `lib/widgets/`, `lib/routing/`, or `providers/` folders just
to match the docs.

## Respect the dependency rule

- **pages/widgets**: render state, collect input, navigate. No sockets, HTTP,
  DNS, ping, or process calls. Dispatch bloc events or call an injected service.
- **bloc**: own screen state and orchestration. Call services through `getIt`,
  emit one terminal state, and keep state local to the feature.
- **services**: perform network and platform work. Return models or streams.
  Do not emit bloc state or import UI widgets.
- **repositories**: own drift queries. No network logic.
- **models**: immutable data structures. Drift tables live in
  `lib/models/drift/`.

Simple one-shot tools may skip a bloc and hold an optional injectable service
in the page, as `WakeOnLanPage` does. Multi-state, streaming, or long-running
flows must use a bloc.

## Design for mobile and desktop

Vernet ships the same Flutter UI to phones and desktop. Treat desktop as a
first-class layout, not a stretched phone.

- Wrap page content in `LayoutBuilder` + `Align(alignment: Alignment.topCenter)`
  + `ConstrainedBox(maxWidth: ...)`. Use about `900` for simple lists, `900–1100`
  for reports, and `1180` for dashboards, matching `home_page.dart`.
- Scale horizontal padding with width: `14–16` on phones, `24+` on desktop.
- Set `crossAxisAlignment: CrossAxisAlignment.stretch` or `.start` explicitly.
  A default `Column` centers its children, which produces a floating header on
  wide screens.
- Never let lists, forms, or body text span the full window width on desktop.
- Use extra width structurally: switch to a summary rail plus results pane, or
  a real table, instead of only making a single column wider. Keep the same
  content stacked on phones.
- Make the design richer and meaningful: use the data already available (counts,
  timings, device types) for summaries and lightweight visuals. Do not copy the
  device detail page's card stack, and do not add decorative filler.
- Use `Expanded`, `Flexible`, `Wrap`, and width breakpoints for rows, and check
  they do not overflow on narrow phones.
- Verify both a `390px` phone width and a `>= 900px` desktop width in widget
  tests. Flutter test reports overflows automatically.

## Scaffold in dependency order

### 1. Model and persistence (only if data is stored)

Add a drift table in `lib/models/drift/` and register it:

```dart
class Foo extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}
```

```dart
@DriftDatabase(tables: [Device, Scan, Foo])
class AppDatabase extends _$AppDatabase { ... }
```

When changing an existing schema, bump `AppDatabase.schemaVersion` and add an
appropriate `MigrationStrategy`. Do not silently change the schema of an
existing install.

### 2. Drift repository

Extend `Repository<T>` from `lib/repository/repository.dart` and annotate with
`@Injectable()`:

```dart
@Injectable()
class FooRepository extends Repository<FooData> {
  FooRepository(this._database);
  final DatabaseService<AppDatabase> _database;

  @override
  Future<List<FooData>> getList() async {
    final database = await _database.open();
    return database!.select(database.foo).get();
  }

  @override
  Future<FooData> put(FooData value) async { /* insert + read back */ }
}
```

Keep queries in the repository, not in services or widgets. Add focused query
methods (`getRecentScans`, `countByScanId`, `getListForScan`) instead of leaking
SQL details upward.

### 3. Service

Create `lib/services/<feature>_service.dart`, or an abstract contract plus an
implementation in `lib/services/impls/` when multiple implementations or fakes
are needed. Annotate concrete classes with `@Injectable()`.

```dart
@Injectable()
class FooService {
  static final _repository = getIt<FooRepository>();

  Stream<FooData> run() async* {
    // network/platform work only
    yield result;
  }
}
```

Return structured models or streams, keep UI concerns out, and guard platform
side effects with `globals.testingActive` where the existing code does
(notifications, mDNS, subnet masks).

### 4. Bloc, events, and state

Create `lib/pages/<feature>/<feature>_bloc/` with `<feature>_bloc.dart`,
`<feature>_event.dart`, and `<feature>_state.dart`. Use freezed union types and
`part` directives exactly like `host_scan_bloc.dart`.

```dart
@injectable
class FooBloc extends Bloc<FooEvent, FooState> {
  FooBloc() : super(FooState.initial()) {
    on<Started>(_onStarted);
  }

  final service = getIt<FooService>();

  Future<void> _onStarted(Started event, Emitter<FooState> emit) async {
    emit(const FooState.loading());
    try {
      await for (final value in service.run()) {
        if (emit.isDone) return;
        emit(FooState.success(value));
      }
    } catch (_) {
      emit(const FooState.failure());
    }
  }
}
```

Events are user intents; states cover `initial`, `loading`, `success`, `empty`,
and `failure`. Emit each terminal state once. Guard stream loops with
`emit.isDone` when a listener can outlive the handler.

### 5. Page and widgets

- Instantiate the bloc with `getIt<FooBloc>()` inside `BlocProvider`.
- Render with `BlocBuilder`/`BlocConsumer`; handle loading, empty, error, and
  success explicitly.
- Constrain the page body on wide windows and keep desktop padding generous;
  see "Design for mobile and desktop".
- Put feature-specific widgets in `lib/pages/<feature>/widgets/`; put shared
  widgets in `lib/ui/`.
- Use `AdaptiveListTile` and related widgets from `lib/ui/adaptive/`. They
  require a `DarkThemeProvider` ancestor.
- Give interactive widgets a `WidgetKey` entry and use
  `key: WidgetKey.<name>.key`.
- Put user-visible text in `StringValue`.
- Show completion or failure feedback with `ScaffoldMessenger`; hide the current
  snackbar before showing a new one.
- Dispose controllers and subscriptions.
- Accept optional repositories/services in the page constructor when tests need
  to inject fakes, matching `ScanHistoryPage`.

Register a new route in `onGenerateRoute` in `lib/main.dart`; do not add a
routing package or a `lib/routing/` folder.

### 6. Code generation

After changing freezed, drift, or injectable annotations, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Never hand-edit `.freezed.dart`, `.g.dart`, or `lib/injection.config.dart`.

### 7. Tests

Mirror the source path:

- `test/pages/<feature>/<feature>_page_test.dart`
- `test/pages/<feature>/<feature>_bloc_test.dart`
- `test/services/<feature>_service_test.dart`
- `test/repository/<model>_repository_test.dart`

Use these established patterns:

**Drift repository test** — in-memory database, mock preferences, close in
teardown:

```dart
class _InMemoryDatabaseService implements DatabaseService<AppDatabase> {
  _InMemoryDatabaseService(this.db);
  final AppDatabase db;
  @override
  Future<AppDatabase?> open() async => db;
}

setUp(() {
  SharedPreferences.setMockInitialValues({});
  db = AppDatabase(NativeDatabase.memory());
  repository = FooRepository(_InMemoryDatabaseService(db));
});

tearDown(() => db.close());
```

**Bloc test** — reset getIt, register a fake service, set
`globals.testingActive = true`, and await emitted states.

**Widget test** — wrap with `wrapWithDarkThemeProvider` from
`test/helpers/test_helpers.dart`.

**Fakes** — `implements` the concrete repository/service, so every added public
method must be implemented in every fake. Search existing fakes when adding a
query method.

**Widget async** — do not use `pumpAndSettle` while an indeterminate
`CircularProgressIndicator` is mounted; it never settles. Prefer a
synchronous fake state, bounded `pump` calls, or test the bloc separately.

**Integration and CI** — follow the `vernet-testing` skill. Nested suites live
under `integration_test/`, omit the `_test.dart` suffix, and are imported and
called from `integration_test/app_test.dart`. Notification tests must set
`NotificationService.debugIgnorePlatformCheck = true` so they also pass on
Windows CI.

## Verify before reporting done

Format only the files you touched:

```bash
dart format lib/pages/<feature> test/pages/<feature> lib/services/<file>.dart
dart analyze
flutter test test/pages/<feature>
flutter test
flutter test integration_test/scan_report/scan_report.dart -d macos
```

Do not run `dart format lib test` across the repository; it rewrites unrelated
files. Do not modify `android/`, `ios/`, `linux/`, `macos/`, or `windows/`
unless the task cannot be done in Dart.

## Definition of done

- [ ] Change lives in the correct layer; no network I/O in widgets.
- [ ] Services return models/streams and have no UI dependencies.
- [ ] Drift queries stay in repositories; schema changes include a migration.
- [ ] Bloc states cover initial, loading, success, empty, and failure.
- [ ] New UI text uses `StringValue`; interactive widgets use `WidgetKey`.
- [ ] Page content is width-constrained and left-aligned on desktop.
- [ ] Layout verified at phone and desktop widths with no overflow.
- [ ] New route registered in `main.dart`.
- [ ] Code generation run for annotation changes.
- [ ] Tests mirror the source path and pass.
- [ ] New integration suites are registered in `integration_test/app_test.dart`.
- [ ] `dart analyze` reports no issues.
- [ ] Diff contains only intended files; no repo-wide formatting churn.
