import '../data/tag_local_data_source.dart';
import 'tag_repository.dart';

final tagRepository = TagRepository(TagLocalDataSource());
