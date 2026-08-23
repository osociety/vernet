import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/injection.dart';

import '../test_port.dart' as test_port;
import 'host_scan_and_port_scan.dart' as host_scan_and_port_scan;
import 'run_scan_on_startup.dart' as run_scan_on_startup;

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ServerSocket? server;

  // Clear database before running wifi tests to prevent stale scan records
  setUpAll(() async {
    // Only initialize if not already initialized
    if (!getIt.isRegistered<DatabaseService<AppDatabase>>()) {
      configureDependencies(Env.test);
      final appDocDirectory = await getApplicationDocumentsDirectory();
      await configureNetworkToolsFlutter(appDocDirectory.path);
    }
    if (test_port.port == 0) {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0, shared: true);
      test_port.port = server!.port;
      debugPrint("Opened port in this machine at ${test_port.port}");
    }
    await clearDatabase();
  });

  host_scan_and_port_scan.main();
  run_scan_on_startup.main();

  // Clear database after all wifi tests complete
  tearDownAll(() async {
    await clearDatabase();
    await server?.close();
  });
}
