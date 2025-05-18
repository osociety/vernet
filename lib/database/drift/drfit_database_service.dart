import 'dart:io';

import 'package:drift/native.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vernet/database/database_service.dart';
import 'package:vernet/database/drift/drift_database.dart';

@Injectable(as: DatabaseService<AppDatabase>)
class DriftDatabaseService extends DatabaseService<AppDatabase> {
  static AppDatabase? appDatabase;
  @override
  Future<AppDatabase?> open() async {
    final databaseDirectory = await getApplicationSupportDirectory();
    return appDatabase ??= AppDatabase(NativeDatabase.createInBackground(
        File(path.join(databaseDirectory.path, 'vernet.db'))));
  }
}
