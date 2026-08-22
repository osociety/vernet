import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';

import 'host_scan_and_port_scan_test.dart' as host_scan_and_port_scan;
import 'run_scan_on_startup_test.dart' as run_scan_on_startup;

/// Clears all scan and device records from the database to prevent
/// "Too many elements" errors when tests query for ongoing scans.
Future<void> clearDatabase() async {
  try {
    final dbService = getIt<DatabaseService<AppDatabase>>();
    final db = await dbService.open();
    if (db == null) {
      debugPrint('Failed to open database for clearing');
      return;
    }
    // Delete all devices first (they have foreign key to scans)
    await db.delete(db.device).go();
    // Then delete all scans
    await db.delete(db.scan).go();
    debugPrint('Database cleared for integration tests');
  } catch (e) {
    debugPrint('Failed to clear database: $e');
  }
}

void main() {
  // Clear database before running wifi tests to prevent stale scan records
  setUpAll(() async {
    // Only initialize if not already initialized
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
    }
    await clearDatabase();
  });

  host_scan_and_port_scan.main();
  run_scan_on_startup.main();

  // Clear database after all wifi tests complete
  tearDownAll(() async {
    await clearDatabase();
  });
}
