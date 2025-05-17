import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/database/drift/drift_database.dart';
import 'package:vernet/helper/utils_helper.dart';
import 'package:vernet/repository/repository.dart';

@Injectable()
class ScanRepository extends Repository<ScanData> {
  final database = AppDatabase();

  Future<ScanData?> get(int id) async {
    return (database.select(database.scan)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<ScanData>> getList() {
    return database.select(database.scan).get();
  }

  @override
  Future<ScanData> put(ScanData t) async {
    final id = await database.into(database.scan).insert(t.toCompanion(true));
    return (database.select(database.scan)..where((dd) => dd.id.equals(id)))
        .getSingle();
  }

  Future<ScanData?> getOnGoingScan() async {
    final ongoingScanId = await getCurrentScanId();
    if (ongoingScanId != null) {
      return get(ongoingScanId);
    }
    return (database.select(database.scan)
          ..where((scan) => scan.onGoing.equals(true))
          ..where((scan) => scan.endTime.equalsNullable(null))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.startTime,
                  mode: OrderingMode.desc,
                ),
          ]))
        .getSingleOrNull();
  }

  Future<Stream<List<ScanData>>> watch(int id) async {
    return (database.select(database.scan)..where((scan) => scan.id.equals(id)))
        .watch();
  }
}
