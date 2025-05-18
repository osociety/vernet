import 'package:drift/drift.dart';

class Device extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scanId => integer().named('scan_id')();
  TextColumn get internetAddress => text().named('internetAddress')();
  TextColumn get currentDeviceIp => text().named('currentDeviceIp')();
  TextColumn get gatewayIp => text().named('gatewayIp')();
  TextColumn get macAddress => text().nullable()();
  TextColumn get hostMake => text().nullable()();
  TextColumn get mdnsDomainName => text().nullable()();
}
