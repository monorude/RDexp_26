import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // ← DateFormat を使うために追加
import 'setting_page.dart';
import 'NormalTask.dart'; // ← 新しいデータモデルをインポート

/// 上部のタブで「未完了」「完了済み」を切り替えられるタスク一覧画面
class MyTabScreen extends StatelessWidget {
  const MyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // タブの数は「未完了」「完了済み」の2つ
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('タスク一覧'),
        ),

        body: Column(
          children: [
            ColoredBox(
              color: Colors.white,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const <Widget>[
                  Tab(icon: Icon(Icons.assignment_late), text: '未完了'),
                  Tab(icon: Icon(Icons.assignment_turned_in), text: '完了済み'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildTaskList(isCompletedFilter: false), // 未完了リスト
                  _buildTaskList(isCompletedFilter: true), // 完了済みリスト
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 完了済みタスクを一括削除する（古いデータ・新モデル両方に対応）
  void _deleteAllCompletedTasks(Box box, Box<NormalTask> normalBox) async {
    final keysToDelete = <String, List<int>>{};

    // 1. 従来の 'tasks' ボックスから一括削除対象を抽出
    for (var key in box.keys) {
      if (key is String &&
          (key.endsWith('_plain') || key.endsWith('_period'))) {
        final list = box.get(key);
        if (list is List) {
          final indices = <int>[];
          for (int i = 0; i < list.length; i++) {
            final task = list[i];
            if (task['isCompleted'] == true) {
              indices.add(i);
            }
          }
          if (indices.isNotEmpty) {
            keysToDelete[key] = indices;
          }
        }
      }
    }

    // 従来のデータを削除
    for (var entry in keysToDelete.entries) {
      final key = entry.key;
      final indices = entry.value;

      final list = (box.get(key) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      indices.sort((a, b) => b.compareTo(a));
      for (var i in indices) {
        list.removeAt(i);
      }

      if (list.isEmpty) {
        await box.delete(key);
      } else {
        await box.put(key, list);
      }

      if (key.endsWith('_period')) {
        final dateKey = key.replaceAll('_period', '');
        final assign = box.get(dateKey, defaultValue: List.filled(5, ''));

        final remaining = list.map((e) => e['periodIndex']).toList();

        for (int p = 0; p < assign.length; p++) {
          if (!remaining.contains(p)) {
            assign[p] = '';
          }
        }

        await box.put(dateKey, assign);
      }
    }

    // 2. 新しい 'normalTasks' ボックスから完了済みを一括削除
    final normalKeysToDelete = [];
    for (var i = 0; i < normalBox.length; i++) {
      final task = normalBox.getAt(i);
      if (task != null && task.isCompleted) {
        normalKeysToDelete.add(normalBox.keyAt(i));
      }
    }
    for (var key in normalKeysToDelete) {
      await normalBox.delete(key);
    }
  }

  /// Hiveからデータを取得してフィルタリングし、リストを構築するヘルパー関数
  Widget _buildTaskList({required bool isCompletedFilter}) {
    // 従来の 'tasks' ボックスの変更をリッスン
    return ValueListenableBuilder(
      valueListenable: Hive.box('tasks').listenable(),
      builder: (context, Box box, _) {
        // 新しい 'normalTasks' ボックスの変更も同時にリッスンしてネストさせる
        return ValueListenableBuilder(
          valueListenable: Hive.box<NormalTask>('normalTasks').listenable(),
          builder: (context, Box<NormalTask> normalBox, _) {
            final List<_TaskItem> filteredTasks = [];

            // 1. 従来の 'tasks' ボックスから Map 形式データを読み込む
            for (var key in box.keys) {
              if (key is String) {
                if (key.endsWith('_plain')) {
                  final dateKey = key.replaceAll('_plain', '');
                  final dynamic savedData = box.get(key);
                  if (savedData is List) {
                    final list = savedData
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    for (int i = 0; i < list.length; i++) {
                      final task = list[i];
                      final isCompleted = task['isCompleted'] as bool? ?? false;
                      if (isCompleted == isCompletedFilter) {
                        filteredTasks.add(
                          _TaskItem(
                            dateKey: dateKey,
                            type: 'plain',
                            index: i,
                            taskData: task,
                          ),
                        );
                      }
                    }
                  }
                } else if (key.endsWith('_period')) {
                  final dateKey = key.replaceAll('_period', '');
                  final dynamic savedData = box.get(key);
                  if (savedData is List) {
                    final list = savedData
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    for (int i = 0; i < list.length; i++) {
                      final task = list[i];
                      final isCompleted = task['isCompleted'] as bool? ?? false;
                      if (isCompleted == isCompletedFilter) {
                        filteredTasks.add(
                          _TaskItem(
                            dateKey: dateKey,
                            type: 'period',
                            index: i,
                            taskData: task,
                          ),
                        );
                      }
                    }
                  }
                }
              }
            }

            // 2. 新しい 'normalTasks' ボックスから NormalTask モデルデータを読み込んで統合
            for (var i = 0; i < normalBox.length; i++) {
              final task = normalBox.getAt(i);
              if (task != null) {
                final isCompleted = task.isCompleted;
                if (isCompleted == isCompletedFilter) {
                  final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate);
                  final timeStr =
                      '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}';

                  // 表示上のレイアウトを共通化するため擬似的な Map 構造を作成
                  final taskMap = {
                    'text': task.title,
                    'time': timeStr,
                    'isCompleted': task.isCompleted,
                    'description': task.description,
                    'tags': task.tags,
                    'periodIndex': task.collegeTime > 0
                        ? task.collegeTime - 1
                        : -1,
                  };

                  filteredTasks.add(
                    _TaskItem(
                      dateKey: dateKey,
                      type: task.collegeTime > 0 ? 'period' : 'plain',
                      index: i,
                      taskData: taskMap,
                      hiveKey: normalBox.keyAt(i), // 削除や編集用の固有キー
                      isNormalTaskModel: true, // 新モデル判別フラグ
                    ),
                  );
                }
              }
            }

            // 表示するタスクがない場合
            if (filteredTasks.isEmpty) {
              return Center(
                child: Text(
                  isCompletedFilter ? '完了したタスクはありません' : 'すべてのタスクが完了しています',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            // 日付順にソート
            filteredTasks.sort((a, b) => a.dateKey.compareTo(b.dateKey));

            // メインのリストビュー（未完了・完了済み共通で同じ綺麗なUIを使用）
            final mainListView = ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final item = filteredTasks[index];
                final task = item.taskData;
                final title = task['text'] as String? ?? '';
                final isCompleted = task['isCompleted'] as bool? ?? false;
                final description = task['description'] as String? ?? '';

                // 新しい 'tags' と 古い 'tag' の両方に安全に対応
                final List<String> tags = [];
                if (task['tags'] is List) {
                  tags.addAll((task['tags'] as List).cast<String>());
                } else if (task['tag'] is String &&
                    (task['tag'] as String).isNotEmpty) {
                  tags.add(task['tag'] as String);
                }

                // 日付部分のテキスト作成
                String dateLine = item.dateKey;
                if (item.type == 'plain') {
                  final time = task['time'] as String? ?? '';
                  if (time.isNotEmpty && time != '00:00' && time != '時刻未設定') {
                    dateLine += ' ($time)';
                  }
                } else if (item.type == 'period') {
                  final periodIndex = task['periodIndex'] as int? ?? -1;
                  if (periodIndex != -1) {
                    dateLine += ' (${periodIndex + 1}限)';
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isCompletedFilter
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompletedFilter ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(dateLine, style: const TextStyle(fontSize: 13)),

                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCompletedFilter
                                  ? Colors.grey
                                  : Colors.black54,
                            ),
                          ),
                        ],

                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6.0,
                            runSpacing: 4.0,
                            children: tags.map((t) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '# $t',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: (bool? value) async {
                        if (value != null) {
                          if (item.isNormalTaskModel) {
                            // ★新モデルの完了状態更新
                            final normalBox = Hive.box<NormalTask>(
                              'normalTasks',
                            );
                            final originalTask = normalBox.get(item.hiveKey);
                            if (originalTask != null) {
                              originalTask.isCompleted = value;
                              await normalBox.put(item.hiveKey, originalTask);
                            }
                          } else {
                            // ★従来の古いデータの完了状態更新
                            final boxKey = '${item.dateKey}_${item.type}';
                            final List? savedData = box.get(boxKey);
                            if (savedData != null) {
                              final list = savedData
                                  .map(
                                    (e) => Map<String, dynamic>.from(e as Map),
                                  )
                                  .toList();
                              list[item.index]['isCompleted'] = value;
                              await box.put(boxKey, list);
                            }
                          }
                        }
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('タスクの削除'),
                            content: Text('「$title」を削除しますか？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  '削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (item.isNormalTaskModel) {
                            // ★新モデルの削除処理
                            final normalBox = Hive.box<NormalTask>(
                              'normalTasks',
                            );
                            await normalBox.delete(item.hiveKey);
                          } else {
                            // ★従来の古いデータの削除処理
                            final boxKey = '${item.dateKey}_${item.type}';
                            final List? savedData = box.get(boxKey);
                            if (savedData != null) {
                              final list = savedData
                                  .map(
                                    (e) => Map<String, dynamic>.from(e as Map),
                                  )
                                  .toList();
                              list.removeAt(item.index);

                              if (list.isEmpty) {
                                await box.delete(boxKey);
                              } else {
                                await box.put(boxKey, list);
                              }

                              if (item.type == 'period') {
                                final periodIndex =
                                    task['periodIndex'] as int? ?? -1;
                                bool hasMoreTasks = list.any(
                                  (t) => t['periodIndex'] == periodIndex,
                                );
                                if (!hasMoreTasks) {
                                  final List? assignList = box.get(
                                    item.dateKey,
                                  );
                                  if (assignList != null) {
                                    final currentAssign = List<String>.from(
                                      assignList,
                                    );
                                    if (periodIndex >= 0 &&
                                        periodIndex < currentAssign.length) {
                                      currentAssign[periodIndex] = '';
                                      await box.put(
                                        item.dateKey,
                                        currentAssign,
                                      );
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            );

            // 完了済みタブの場合だけ一括削除ボタンを上部にくっつけて返す
            if (isCompletedFilter) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('完了済みタスクをすべて削除'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('一括削除'),
                            content: const Text('完了済みタスクをすべて削除しますか？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  '削除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          _deleteAllCompletedTasks(box, normalBox);
                        }
                      },
                    ),
                  ),
                  Expanded(child: mainListView),
                ],
              );
            }

            // 未完了タブの場合はリストをそのまま返す
            return mainListView;
          },
        );
      },
    );
  }
}

class _TaskItem {
  final String dateKey;
  final String type;
  final int index;
  final Map<String, dynamic> taskData;
  final dynamic hiveKey; // 新モデル用のキーを保持するため追加
  final bool isNormalTaskModel; // 新モデルかどうかのフラグを追加

  _TaskItem({
    required this.dateKey,
    required this.type,
    required this.index,
    required this.taskData,
    this.hiveKey,
    this.isNormalTaskModel = false,
  });
}
