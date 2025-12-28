import 'package:hive/hive.dart';

part 'favorite.g.dart';

@HiveType(typeId: 0)
class Favorite extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final bool isDirectory;

  Favorite({required this.path, required this.name, required this.isDirectory});
}
