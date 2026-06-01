import 'package:hive/hive.dart';

class TaskService {
  final Box taskBox = Hive.box('tasks');

  // 課題一覧を取得
  List<Map<String, dynamic>> getTasks() {
    return taskBox.values.map((e) {
      return {
        'title': e['title'],
        'deadline': DateTime.parse(e['deadline']),
        'isDone': e['isDone'],
      };
    }).toList();
  }

  // 課題を追加
  Future<void> addTask(String title, DateTime deadline) async {
    await taskBox.add({
      'title': title,
      'deadline': deadline.toIso8601String(),
      'isDone': false,
    });
  }

  // 課題を削除
  Future<void> deleteTask(int index) async {
    await taskBox.deleteAt(index);
  }

  // 完了チェックの切り替え
  Future<void> toggleDone(int index) async {
    final task = taskBox.getAt(index);
    if (task != null) {
      task['isDone'] = !task['isDone'];
      await taskBox.putAt(index, task);
    }
  }
}
