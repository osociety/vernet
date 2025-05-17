import 'package:isar/isar.dart';

abstract class DatabaseService {
  Future<Isar?> open();
}
