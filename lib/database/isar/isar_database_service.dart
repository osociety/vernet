import 'package:injectable/injectable.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/isar/scan.dart';

@Injectable(as: DatabaseService<Isar>)
class IsarDatabaseService extends DatabaseService<Isar> {
  static Isar? isarDb;
  @override
  Future<Isar?> open() async {
    return isarDb ??= await Isar.open(
      [ScanSchema, DeviceSchema],
      directory: (await getApplicationDocumentsDirectory()).path,
    );
  }
}
