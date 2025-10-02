import '../data/tag_local_data_source.dart';
import '../models/tag.dart';

class TagRepository {
  final TagLocalDataSource dataSource;
  TagRepository(this.dataSource);

  Future<bool> exists(String epc) async => (await dataSource.getByEpc(epc)) != null;

  Future<void> save(String epc, String name) async {
    if (await exists(epc)) {
      // If tag already exists, update it with new name
      await rename(epc, name);
      return;
    }
    await dataSource.put(Tag(epc: epc, name: name));
  }

  Future<void> rename(String epc, String newName) async {
    final tag = await dataSource.getByEpc(epc);
    if (tag == null) return;
    tag.name = newName;
    await dataSource.put(tag);
  }

  Future<void> remove(String epc) async => dataSource.delete(epc);
  Future<Tag?> get(String epc) async => dataSource.getByEpc(epc);
  Future<List<Tag>> getAll() async => dataSource.getAll();
}
