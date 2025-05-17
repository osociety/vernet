import 'package:drift/drift.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/repository.dart';

class DeviceRepository extends Repository<DeviceData> {
  final database = AppDatabase();

  Future<DeviceData?> get(int id) async {
    return (database.select(database.device)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<DeviceData>> getList() {
    return database.select(database.device).get();
  }

  @override
  Future<DeviceData> put(DeviceData t) async {
    await database.into(database.device).insert(t.toCompanion(true));
    return (database.select(database.device)
          ..where((dd) => dd.internetAddress.equals(t.internetAddress)))
        .getSingle();
  }

  Future<DeviceData?> getDevice(int scanId, String address) async {
    return (database.select(database.device)
          ..where((dd) => dd.internetAddress.equals(address))
          ..where((dd) => dd.scanId.equals(scanId)))
        .getSingle();
  }

  Future<Stream<List<DeviceData>>> watch(int scanId) async {
    return (database.select(database.device)
          ..where((dd) => dd.scanId.equals(scanId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.internetAddress),
          ]))
        .watch();
  }

  Future<int> countByScanId(int scanId) async {
    return int.parse(
      (database.selectOnly(database.device)
            ..addColumns(
              [countAll(filter: database.device.scanId.equals(scanId))],
            ))
          .map(
            (row) => row.read(
              countAll(filter: database.device.id.equals(scanId)),
            ),
          )
          .getSingle()
          .toString(),
    );
  }
}
