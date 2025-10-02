import 'package:hive_ce/hive.dart';

part 'tag.g.dart';

@HiveType(typeId: 1)
class Tag {
  @HiveField(0)
  final String epc; // unique key, immutable

  @HiveField(1)
  String name; // user editable

  Tag({required this.epc, required this.name});
}
