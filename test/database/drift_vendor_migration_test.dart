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

/// Leaves a database file without the trust registry, as an install made
/// before the registry shipped would have it.
Future<File> _seedDatabaseWithoutTrustRegistry(
  Directory dir,
  String name, {
  required int userVersion,
}) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  final database = AppDatabase(NativeDatabase(file));
  await database.customStatement('DROP TABLE known_device');
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

  group('known_device migration', () {
    Future<void> expectRegistryUsable(AppDatabase database) async {
      await database.customStatement(
        'INSERT INTO known_device (device_key, last_address, first_seen_at, '
        'last_seen_at) VALUES (?, ?, ?, ?)',
        ['mac:00:03:93:aa:bb:01', '192.168.0.5', 1767225600, 1767225600],
      );
      final stored = await database.select(database.knownDevice).getSingle();
      expect(stored.deviceKey, 'mac:00:03:93:aa:bb:01');
      expect(stored.trusted, isFalse);
    }

    test('upgrading from schema version 4 creates the trust registry',
        () async {
      final file = await _seedDatabaseWithoutTrustRegistry(
        tempDir,
        'trust-upgrade.sqlite',
        userVersion: 4,
      );

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      await expectRegistryUsable(upgraded);
    });

    test('a version-5 database that predates the registry is repaired on open',
        () async {
      // The registry was added after version 5 was already being stamped, so
      // onUpgrade never runs on those installs and beforeOpen has to repair it.
      final file = await _seedDatabaseWithoutTrustRegistry(
        tempDir,
        'trust-repair.sqlite',
        userVersion: 5,
      );

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);

      await expectRegistryUsable(reopened);
    });
  });
}
