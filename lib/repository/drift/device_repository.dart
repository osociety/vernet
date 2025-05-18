import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/repository/repository.dart';

@Injectable()
class DeviceRepository extends Repository<DeviceData> {
  DeviceRepository(this._database);
  final DatabaseService<AppDatabase> _database;

  Future<DeviceData?> get(int id) async {
    final database = await _database.open();
    return (database!.select(database.device)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<DeviceData>> getList() async {
    final database = await _database.open();
    return database!.select(database.device).get();
  }

  @override
  Future<DeviceData> put(DeviceData t) async {
    final database = await _database.open();
    final id =
        await database!.into(database.device).insert(t.toCompanion(true));
    return (database.select(database.device)..where((dd) => dd.id.equals(id)))
        .getSingle();
  }

  Future<DeviceData?> getDevice(int scanId, String address) async {
    final database = await _database.open();
    return (database!.select(database.device)
          ..where((dd) => dd.internetAddress.equals(address))
          ..where((dd) => dd.scanId.equals(scanId)))
        .getSingleOrNull();
  }

  Future<Stream<List<DeviceData>>> watch(int scanId) async {
    final database = await _database.open();
    return (database!.select(database.device)
          ..where((dd) => dd.scanId.equals(scanId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.internetAddress),
          ]))
        .watch();
  }

  Future<int> countByScanId(int scanId) async {
    final database = await _database.open();
    return int.parse(
      (database!.selectOnly(database.device)
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
