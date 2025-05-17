abstract class Repository<T> {
  Future<List<T>> getList();
  Future<T> put(T t);
}
