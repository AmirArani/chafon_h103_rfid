<!-- 69c0e2e2-75c8-4e7e-8edc-3f7f1bf91f58 092aba9b-d7e9-43d9-88cb-eec0f0210680 -->
# Implement Saved Tags with Hive CE

#### 1) Add dependencies and codegen
- Add to `pubspec.yaml` dependencies:
  - `hive_ce`, `hive_ce_flutter`
- Add dev dependencies:
  - `build_runner`, `hive_ce_generator`
- After files are created, run:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

#### 2) Define model and adapter
- Create `lib/models/tag.dart`:
```dart
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
```
- Generated file: `lib/models/tag.g.dart` (via build_runner).

#### 3) Hive init
- Update `lib/main.dart` to initialize Hive and register adapter before `runApp`:
```dart
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'models/tag.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TagAdapter());
  await Hive.openBox<Tag>('tagsBox');
  runApp(MaterialApp(home: const DeviceScanScreen()));
}
```

#### 4) Data source and repository split
- Create `lib/data/tag_local_data_source.dart`:
```dart
import 'package:hive_ce/hive.dart';
import '../models/tag.dart';

class TagLocalDataSource {
  static const String boxName = 'tagsBox';
  Future<Box<Tag>> _box() async => Hive.isBoxOpen(boxName)
      ? Hive.box<Tag>(boxName)
      : await Hive.openBox<Tag>(boxName);

  Future<Tag?> getByEpc(String epc) async => (await _box()).get(epc);
  Future<List<Tag>> getAll() async => (await _box()).values.toList();
  Future<void> put(Tag tag) async => (await _box()).put(tag.epc, tag);
  Future<void> delete(String epc) async => (await _box()).delete(epc);
}
```
- Create `lib/repositories/tag_repository.dart`:
```dart
import '../data/tag_local_data_source.dart';
import '../models/tag.dart';

class TagRepository {
  final TagLocalDataSource dataSource;
  TagRepository(this.dataSource);

  Future<bool> exists(String epc) async => (await dataSource.getByEpc(epc)) != null;
  Future<void> save(String epc, String name) async {
    if (await exists(epc)) return; // EPC unique, ignore duplicates
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
```

#### 5) Wire repository into UI (minimal DI)
- Create a simple app-level instance in `lib/repositories/instances.dart`:
```dart
import '../data/tag_local_data_source.dart';
import 'tag_repository.dart';

final tagRepository = TagRepository(TagLocalDataSource());
```

#### 6) Continuous Read tab changes in `lib/functions.dart`
- State: add `Map<String, String> savedNamesByEpc = {};`
- In `initState()`, load once:
```dart
Future<void> _loadSaved() async {
  final all = await tagRepository.getAll();
  if (!mounted) return;
  setState(() { savedNamesByEpc = { for (final t in all) t.epc: t.name }; });
}
```
- Call `_loadSaved()` after Hive init (on first build/initState).
- In `_buildContinuousInventoryTab()` ListTile, change title/subtitle and trailing:
```dart
final savedName = savedNamesByEpc[epc];
final title = savedName != null ? 'Name: $savedName' : 'EPC: $epc';
// trailing
trailing: savedName == null
  ? IconButton(icon: const Icon(Icons.save), onPressed: () async {
      final name = await _promptForName(context, epc);
      if (name == null) return;
      await tagRepository.save(epc, name);
      await _loadSaved();
    })
  : const Icon(Icons.verified, color: Colors.green),
```
- Add `_promptForName(BuildContext, String epc)` dialog returning `String?`.

#### 7) Single Read tab changes
- Track EPC of last single read: add `String lastSingleEpc = '';`
- In `onTagReadSingle`, set `lastSingleEpc = epc;`
- Under the result container, show save-or-name row similarly using `savedNamesByEpc` and repository calls.

#### 8) Radar tab changes
- Above the `TextField`, add a `DropdownButton<Tag>` populated from `await tagRepository.getAll()` and/or a cached list; when user selects, set `epcController.text = selected.epc`.
- Keep manual EPC entry available.

#### 9) Settings tab: Saved Tags management
- Add a new section at the top or bottom titled “Saved Tags”.
- Render a `FutureBuilder` or cached list of `Tag`, each row with:
  - leading name and EPC
  - actions: Rename (opens name dialog then `repository.rename`) and Delete (confirm then `repository.remove`).
- After operations, refresh from repository.

#### 10) UX helpers
- Implement `_promptForName` dialog in `Functions` to reuse for Save/Rename.
- SnackBars on success/failure for save/rename/delete.

#### 11) Testing note
- Ensure EPC uniqueness enforced by repository (box key = EPC) and that UI gracefully handles duplicate save attempts.



### To-dos

- [ ] Add Hive CE deps, generator, run build_runner
- [ ] Create Tag model and generate adapter
- [ ] Create Hive TagLocalDataSource (open box, CRUD)
- [ ] Create TagRepository (save, rename, remove, list)
- [ ] Initialize Hive and register TagAdapter in main.dart
- [ ] Create repository instance for app and import where needed
- [ ] Update Continuous tab to show name or Save button
- [ ] Update Single Read tab to show name/save for last EPC
- [ ] Add saved-tags dropdown to Radar, keep manual entry
- [ ] Add Saved Tags management (list, rename, delete)