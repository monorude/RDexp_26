import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class NormalTask extends HiveObject {
  @HiveField(0)
  late String title;

  @HiveField(1)
  late String description;

  @HiveField(2)
  late DateTime dueDate;

  @HiveField(3)
  late bool isCompleted;

  @HiveField(4)
  late List<String> tags; // 🔥 String から List<String> に変更し、複数形(tags)に

  @HiveField(5)
  late int collegeTime;

  // 🔥 繰り返し設定・非通知設定のフィールドを追加
  @HiveField(6)
  String? repeatInterval; // '週' | '隔週' | '月' | null

  @HiveField(7)
  String? repeatEndType; // '月' | '年' | '前期' | '後期' | null

  @HiveField(8)
  late bool isMuted; // 非通知フラグ

  NormalTask({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.isCompleted,
    required this.tags, // 🔥 tags に変更
    required this.collegeTime,
    this.repeatInterval, // 🔥 追加（任意入力のため required なし）
    this.repeatEndType, // 🔥 追加（任意入力のため required なし）
    this.isMuted = false, // 🔥 追加（デフォルトは通知する＝false）
  });
}
