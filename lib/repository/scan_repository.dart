import 'package:injectable/injectable.dart';
import 'package:isar/isar.dart';
import 'package:vernet/models/isar/scan.dart';
import 'package:vernet/repository/repository.dart';
import 'package:vernet/services/database_service.dart';

@Injectable()
class ScanRepository extends IsarRepository<Scan> {
  ScanRepository(this._database);
  final DatabaseService _database;

  @override
  Future<List<Scan>> getList() async {
    final scanDB = await _database.open();
    return scanDB!.scans.where().findAll();
  }

  @override
  Future<Scan?> get(Id id) async {
    final scanDB = await _database.open();
    return scanDB!.scans.get(id);
  }

  @override
  Future<Scan> put(Scan scan) async {
    final scanDB = await _database.open();
    await scanDB!.writeTxn(() async {
      await scanDB.scans.put(scan);
    });
    return scan;
  }

  Future<Scan?> getOnGoingScan() async {
    final scanDB = await _database.open();
    return scanDB!.scans
        .filter()
        .onGoingEqualTo(true)
        .endTimeEqualTo(null)
        .sortByStartTimeDesc()
        .findFirst();
  }
}
