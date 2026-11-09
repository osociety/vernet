import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/models/drift/device.dart';
import 'package:vernet/models/drift/scan.dart';

part 'drift_database.g.dart';

@DriftDatabase(tables: [Device, Scan])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          if (details.wasCreated) return;

          // Handle databases created before migration support was added.
          // Check if device_type column exists, add it if missing.
          try {
            await customStatement('SELECT device_type FROM device LIMIT 0');
          } catch (_) {
            debugPrint('Adding missing device_type column');
            await customStatement(
                'ALTER TABLE device ADD COLUMN device_type TEXT');
          }

          // Check if open_ports column exists, add it if missing.
          try {
            await customStatement('SELECT open_ports FROM device LIMIT 0');
          } catch (_) {
            debugPrint('Adding missing open_ports column');
            await customStatement(
                'ALTER TABLE device ADD COLUMN open_ports TEXT');
          }

          // Check if vendor_name column exists, add it if missing.
          try {
            await customStatement('SELECT vendor_name FROM device LIMIT 0');
          } catch (_) {
            debugPrint('Adding missing vendor_name column');
            await customStatement(
                'ALTER TABLE device ADD COLUMN vendor_name TEXT');
          }
        },
        onUpgrade: (m, from, to) async {
          debugPrint('Database upgrade from version $from to $to');
          // Use customStatement to check if columns exist before adding
          if (from < 2) {
            try {
              await customStatement('SELECT device_type FROM device LIMIT 0');
            } catch (_) {
              await m.addColumn(device, device.deviceType);
            }
          }
          if (from < 3) {
            try {
              await customStatement('SELECT open_ports FROM device LIMIT 0');
            } catch (_) {
              await m.addColumn(device, device.openPorts);
            }
          }
          if (from < 4) {
            try {
              await customStatement('SELECT vendor_name FROM device LIMIT 0');
            } catch (_) {
              await m.addColumn(device, device.vendorName);
            }
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'vernet',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}
