import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class NormalTask extends HiveObject {
  @HiveField(0)
  late String id ;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String description;

  @HiveField(3)
  late DateTime dueDate;

  @HiveField(4)
  late bool isCompleted;

  @HiveField(5)
  late String tag;

  @HiveField(6)
  late int collegeTime;

NormalTask({
  required this.id,
  required this.title,
  required this.description,
  required this.dueDate,
  required this.isCompleted,
  required this.tag,
  required this.collegeTime,
});
}