import 'package:isar/isar.dart';

abstract class IsarRepository<T> {
  Future<List<T>> getList();
  Future<T?> get(Id id);
  Future<T> put(T t);
}
