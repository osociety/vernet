import 'package:drift/drift.dart';

/// A device the app has seen at least once, with the user's trust decision.
///
/// Trust is keyed by the device itself instead of by a scan row: scans insert a
/// new row for every discovery, so a per-row flag would forget the decision as
/// soon as the next scan started. The MAC is the key whenever one was resolved
/// because it survives the address changes between scans; [deviceKey] falls
/// back to the address for adapters that expose no MAC.
class KnownDevice extends Table {
  TextColumn get deviceKey => text().named('device_key')();
  TextColumn get macAddress => text().nullable().named('mac_address')();
  TextColumn get lastAddress => text().named('last_address')();
  TextColumn get label => text().nullable()();
  BoolColumn get trusted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get firstSeenAt => dateTime().named('first_seen_at')();
  DateTimeColumn get lastSeenAt => dateTime().named('last_seen_at')();
  IntColumn get lastScanId => integer().nullable().named('last_scan_id')();

  @override
  Set<Column> get primaryKey => {deviceKey};
}
