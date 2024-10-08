import 'package:injectable/injectable.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vernet/models/isar/device.dart';
import 'package:vernet/models/isar/scan.dart';
import 'package:vernet/services/database_service.dart';

@Injectable(as: DatabaseService)
class IsarDatabaseService extends DatabaseService {
  static Isar? isarDb;
  @override
  Future<Isar?> open() async {
    return isarDb ??= await Isar.open(
      [ScanSchema, DeviceSchema],
      directory: (await getApplicationDocumentsDirectory()).path,
    );
  }
}
