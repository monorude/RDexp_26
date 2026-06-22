import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'setting_page.dart';

/// 上部のタブで「未完了」「完了済み」を切り替えられるタスク一覧画面
class MyTabScreen extends StatelessWidget {
  const MyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // タブの数は「未完了」「完了済み」の2つ
      child: Scaffold(
        // ★修正：他の画面と完全に同じ見た目・高さにするため、AppBarはシンプルに保ちます
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('タスク一覧'),
        ),
        // 左側の三本線メニュー（ドロワー）の設定
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'aaa',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.message),
                title: Text('Messages'),
              ),
              const ListTile(
                leading: Icon(Icons.account_circle),
                title: Text('Profile'),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('hoges'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // ★修正：body を Column で分割し、一番上に白い背景のタブエリアを配置します
        body: Column(
          children: [
            ColoredBox(
              color: Colors.white, // ← タブの背景を真っ白に指定
              child: TabBar(
                // 白背景の上で綺麗に見えるよう、文字とアイコンの色を調整
                labelColor: Theme.of(
                  context,
                ).colorScheme.primary, // 選択中（メインの紫色など）
                unselectedLabelColor: Colors.grey, // 未選択（グレー）
                indicatorColor: Theme.of(context).colorScheme.primary, // 下線の色
                tabs: const <Widget>[
                  Tab(icon: Icon(Icons.assignment_late), text: '未完了'),
                  Tab(icon: Icon(Icons.assignment_turned_in), text: '完了済み'),
                ],
              ),
            ),
            // 残りの下のスペース全体にタスクリスト（TabBarView）を表示
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

  /// Hiveからデータを取得してフィルタリングし、リストを構築するヘルパー関数
  Widget _buildTaskList({required bool isCompletedFilter}) {
    return ValueListenableBuilder(
      valueListenable: Hive.box(
        'tasks',
      ).listenable(), // ホーム画面と同じ 'tasks' ボックスを監視
      builder: (context, Box box, _) {
        final List<_TaskItem> filteredTasks = [];

        // Box内のすべてのキーを走査して、ホーム画面のタスクデータを集める
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

        if (filteredTasks.isEmpty) {
          return Center(
            child: Text(
              isCompletedFilter ? '完了したタスクはありません' : 'すべてのタスクが完了しています',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

void _deleteAllCompletedTasks(Box box) async {
  final keysToDelete = <String, List<int>>{};

  for (var key in box.keys) {
    if (key is String && (key.endsWith('_plain') || key.endsWith('_period'))) {
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
}

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
              _deleteAllCompletedTasks(box);
            }
          },
        ),
      ),

      // ★ 完了済みタブでも個別削除・チェック操作を使う
      Expanded(
        child: _buildTaskListView(filteredTasks),
      ),
    ],
  );
}



      
        // 日付順に並び替え
        filteredTasks.sort((a, b) => a.dateKey.compareTo(b.dateKey));

        return ListView.builder(
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) {
            final item = filteredTasks[index];
            final task = item.taskData;
            final title = task['text'] as String? ?? '';
            final isCompleted = task['isCompleted'] as bool? ?? false;

            // サブタイトル（日付と、あれば時限・時刻）の作成
            String subtitle = item.dateKey;
            if (item.type == 'plain') {
              final time = task['time'] as String? ?? '時刻未設定';
              subtitle += ' ($time)';
            } else if (item.type == 'period') {
              final periodIndex = task['periodIndex'] as int? ?? -1;
              if (periodIndex != -1) {
                subtitle += ' (${periodIndex + 1}限)';
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  title,
                  style: TextStyle(
                    decoration: isCompletedFilter
                        ? TextDecoration.lineThrough
                        : null,
                    color: isCompletedFilter ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: Text(subtitle),
                leading: Checkbox(
                  value: isCompleted,
                  onChanged: (bool? value) async {
                    if (value != null) {
                      final boxKey = '${item.dateKey}_${item.type}';
                      final List? savedData = box.get(boxKey);
                      if (savedData != null) {
                        final list = savedData
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList();
                        list[item.index]['isCompleted'] = value;
                        await box.put(boxKey, list);
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
                      final boxKey = '${item.dateKey}_${item.type}';
                      final List? savedData = box.get(boxKey);
                      if (savedData != null) {
                        final list = savedData
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList();
                        list.removeAt(item.index);

                        if (list.isEmpty) {
                          await box.delete(boxKey);
                        } else {
                          await box.put(boxKey, list);
                        }

                        // 時限タスクを削除した際、カレンダーのドットマーク(assignments)の消去判定
                        if (item.type == 'period') {
                          final periodIndex = task['periodIndex'] as int? ?? -1;
                          bool hasMoreTasks = list.any(
                            (t) => t['periodIndex'] == periodIndex,
                          );
                          if (!hasMoreTasks) {
                            final List? assignList = box.get(item.dateKey);
                            if (assignList != null) {
                              final currentAssign = List<String>.from(
                                assignList,
                              );
                              if (periodIndex >= 0 &&
                                  periodIndex < currentAssign.length) {
                                currentAssign[periodIndex] = '';
                                await box.put(item.dateKey, currentAssign);
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
      },
    );
  }
}

Widget _buildTaskListView(List<_TaskItem> filteredTasks) {
  return ListView.builder(
    itemCount: filteredTasks.length,
    itemBuilder: (context, index) {
      final item = filteredTasks[index];
      final task = item.taskData;
      final title = task['text'] ?? '';
      final isCompleted = task['isCompleted'] ?? false;

      String subtitle = item.dateKey;
      if (item.type == 'plain') {
        subtitle += ' (${task['time']})';
      } else {
        subtitle += ' (${(task['periodIndex'] as int) + 1}限)';
      }

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Text(subtitle),

          // ★ 完了⇄未完了の切り替え（チェックボックス）
          leading: Checkbox(
            value: isCompleted,
            onChanged: (bool? value) async {
              if (value != null) {
                final box = Hive.box('tasks');
                final boxKey = '${item.dateKey}_${item.type}';
                final List? savedData = box.get(boxKey);

                if (savedData != null) {
                  final list = savedData
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  list[item.index]['isCompleted'] = value;
                  await box.put(boxKey, list);
                }
              }
            },
          ),

          // ★ 個別削除ボタン
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
                final box = Hive.box('tasks');
                final boxKey = '${item.dateKey}_${item.type}';
                final List? savedData = box.get(boxKey);

                if (savedData != null) {
                  final list = savedData
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();

                  list.removeAt(item.index);

                  if (list.isEmpty) {
                    await box.delete(boxKey);
                  } else {
                    await box.put(boxKey, list);
                  }

                  // period の場合は assignments の更新も必要
                  if (item.type == 'period') {
                    final periodIndex = task['periodIndex'] as int? ?? -1;
                    bool hasMoreTasks = list.any(
                      (t) => t['periodIndex'] == periodIndex,
                    );

                    if (!hasMoreTasks) {
                      final List? assignList = box.get(item.dateKey);
                      if (assignList != null) {
                        final currentAssign = List<String>.from(assignList);
                        if (periodIndex >= 0 &&
                            periodIndex < currentAssign.length) {
                          currentAssign[periodIndex] = '';
                          await box.put(item.dateKey, currentAssign);
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
}



class _TaskItem {
  final String dateKey;
  final String type;
  final int index;
  final Map<String, dynamic> taskData;

  _TaskItem({
    required this.dateKey,
    required this.type,
    required this.index,
    required this.taskData,
  });
}
