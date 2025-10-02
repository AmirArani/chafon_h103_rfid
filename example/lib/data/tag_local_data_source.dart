import 'package:hive_ce/hive.dart';
import '../models/tag.dart';

class TagLocalDataSource {
  static const String boxName = 'tagsBox';

  Future<Box<Tag>> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box<Tag>(boxName) : await Hive.openBox<Tag>(boxName);

  Future<Tag?> getByEpc(String epc) async => (await _box()).get(epc);
  Future<List<Tag>> getAll() async => (await _box()).values.toList();
  Future<void> put(Tag tag) async => (await _box()).put(tag.epc, tag);
  Future<void> delete(String epc) async => (await _box()).delete(epc);
}
