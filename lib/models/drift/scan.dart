import 'package:drift/drift.dart';

class Scan extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get gatewayIp => text().named('gatewayIp')();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  BoolColumn get onGoing => boolean().nullable()();
}
