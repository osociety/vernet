import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/database/drift/drift_database.dart';

/// Creates a database, drops the vendor_name column and records
/// [userVersion], leaving a file that a real install would have on disk.
Future<File> _seedDatabaseWithoutVendor(
  Directory dir,
  String name, {
  required int userVersion,
}) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final database = AppDatabase(NativeDatabase(file));
  await database.customStatement(
    'INSERT INTO device (id, scan_id, internetAddress, currentDeviceIp, '
    'gatewayIp) VALUES (?, ?, ?, ?, ?)',
    const [1, 7, '192.168.0.5', '192.168.0.100', '192.168.0.1'],
  );
  await database.customStatement('ALTER TABLE device DROP COLUMN vendor_name');
  await database.customStatement('PRAGMA user_version = $userVersion');
  await database.close();
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vernet_migration');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('vendor_name migration', () {
    test('upgrading from schema version 3 restores the column', () async {
      final file = await _seedDatabaseWithoutVendor(
        tempDir,
        'upgrade.sqlite',
        userVersion: 3,
      );

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      final restored = await upgraded.select(upgraded.device).getSingle();
      expect(restored.internetAddress, '192.168.0.5');
      expect(restored.vendorName, isNull);

      await upgraded
          .update(upgraded.device)
          .replace(restored.copyWith(vendorName: const Value('Apple, Inc.')));

      expect((await upgraded.select(upgraded.device).getSingle()).vendorName,
          'Apple, Inc.');
    });

    test('a database already at the current version is repaired on open',
        () async {
      // Installations created before migration support recorded the current
      // user_version while missing later columns, so onUpgrade never runs.
      final file = await _seedDatabaseWithoutVendor(
        tempDir,
        'backfill.sqlite',
        userVersion: 4,
      );

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);

      final restored = await reopened.select(reopened.device).getSingle();
      expect(restored.vendorName, isNull);

      await reopened
          .update(reopened.device)
          .replace(restored.copyWith(vendorName: const Value('NETGEAR')));

      expect((await reopened.select(reopened.device).getSingle()).vendorName,
          'NETGEAR');
    });
  });
}
