import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/table_calender_sample.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'setting_page.dart';
import 'add_event_screen.dart';
import 'NormalTask.dart';
import 'normal_task_adapter.dart';
import 'task_list_screen.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 起動時に自動削除設定を参照し、期限切れタスクキーを削除する
void _runAutoDelete(Box box) {
  final enabled = box.get('auto_delete_enabled', defaultValue: false) as bool;
  if (!enabled) return;

  const durationDays = {'1ヶ月': 30, '3ヶ月': 90, '6ヶ月': 180, '1年': 365, '2年': 730};

  final durationKey =
      box.get('auto_delete_duration', defaultValue: '1ヶ月') as String;
  final days = durationDays[durationKey] ?? 30;
  final cutoff = DateTime.now().subtract(Duration(days: days));

  final expiredKeys = box.keys.where((k) {
    if (k is! String) return false;
    final dateStr = k.replaceAll(RegExp(r'_(plain|period)$'), '');
    final date = DateTime.tryParse(dateStr);
    return date != null && date.isBefore(cutoff);
  }).toList();

  if (expiredKeys.isNotEmpty) {
    box.deleteAll(expiredKeys);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('tasks'); // ← 課題保存用 Box
  _runAutoDelete(Hive.box('tasks'));
  Hive.registerAdapter(NormalTaskAdapter());
  await Hive.openBox<NormalTask>('normalTasks'); // ← 新しい予定・繰り返し用 Box

  // タイムゾーン初期化
  tz.initializeTimeZones();

  // 通知初期化
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: android, iOS: ios);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  initializeDateFormatting('ja');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'ホーム'),
    );
  }
}

class ClockTimer extends StatefulWidget {
  @override
  State<ClockTimer> createState() {
    return _ClockTimerState();
  }
}

class _ClockTimerState extends State<ClockTimer> {
  String _time = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimer);
  }

  void _onTimer(Timer timer) {
    if (!mounted) return;

    var now = DateTime.now();
    var date = DateFormat.Hms('ja').format(now).toString();
    var timeString = DateFormat.yMMMMEEEEd('ja').format(now).toString();
    setState(() => _time = '$timeString $date ');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_time);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  bool _isFabExpanded = false;
  int _notificationId = 0;

  bool _isCalendarCollapsed = false;

  // ✨ 新しく追加：プロファイル管理用の変数
  List<String> _profiles = ['1年次'];
  String _currentProfile = '1年次';

  Future<void> scheduleNotification({
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _notificationId++;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _notificationId,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_channel',
          'Scheduled Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 従来のMap形式で保存するための古いメソッド（互換性のために維持）
  void _addNewAssignment(
    String dateKey,
    int? periodIndex,
    String text,
    TimeOfDay? time,
    String subjectName,
    String description,
    String tag,
  ) async {
    final box = Hive.box('tasks');
    if (periodIndex != null && periodIndex != -1) {
      setState(() {
        if (!periodTasks.containsKey(dateKey)) {
          periodTasks[dateKey] = [];
        }
        periodTasks[dateKey]!.add({
          'text': text,
          'isCompleted': false,
          'periodIndex': periodIndex,
          'description': description,
          'tag': tag,
        });

        if (!assignments.containsKey(dateKey)) {
          assignments[dateKey] = List.generate(periods.length, (_) => '');
        }
        assignments[dateKey]![periodIndex] = 'has_task';
      });
      await box.put('${dateKey}_period', periodTasks[dateKey]);
      await box.put(dateKey, assignments[dateKey]);
    } else {
      final String timeStr = time != null
          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
          : '時刻未設定';
      setState(() {
        if (!plainTasks.containsKey(dateKey)) {
          plainTasks[dateKey] = [];
        }
        plainTasks[dateKey]!.add({
          'time': timeStr,
          'text': text,
          'isCompleted': false,
          'description': description,
          'tag': tag,
        });
      });

      await box.put('${dateKey}_plain', plainTasks[dateKey]);
    }

    if (time != null) {
      final DateTime parsedDate = DateTime.parse(dateKey);
      final notifyDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        time.hour,
        time.minute,
      );
      if (notifyDate.isAfter(DateTime.now())) {
        scheduleNotification(
          dateTime: notifyDate,
          title: (periodIndex != null && periodIndex != -1)
              ? '📌 ${subjectName.isEmpty ? "空きコマ" : subjectName}'
              : '📌 予定・タスク',
          body: text,
        );
      } else {
        print('【通知スキップ】設定された時刻（$notifyDate）が過去のため、通知は登録されませんでした。');
      }
    }
  }

  final List<String> days = ['月', '火', '水', '木', '金'];
  final List<String> periods = ['1', '2', '3', '4', '5'];

  late List<List<String>> timetable1;
  late List<List<String>> timetable2;

  DateTime? semester1Start;
  DateTime? semester1End;
  DateTime? semester2Start;
  DateTime? semester2End;

  DateTime? _selectedDay;
  Map<String, List<String>> assignments = {};
  Map<String, List<Map<String, dynamic>>> periodTasks = {};
  Map<String, List<Map<String, dynamic>>> plainTasks = {};

  List<List<String>>? _getTimetableForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    if (semester1Start != null && semester1End != null) {
      final start = DateTime(
        semester1Start!.year,
        semester1Start!.month,
        semester1Start!.day,
      );
      final end = DateTime(
        semester1End!.year,
        semester1End!.month,
        semester1End!.day,
      );
      if ((target.isAfter(start) || target.isAtSameMomentAs(start)) &&
          (target.isBefore(end) || target.isAtSameMomentAs(end))) {
        return timetable1;
      }
    }

    if (semester2Start != null && semester2End != null) {
      final start = DateTime(
        semester2Start!.year,
        semester2Start!.month,
        semester2Start!.day,
      );
      final end = DateTime(
        semester2End!.year,
        semester2End!.month,
        semester2End!.day,
      );
      if ((target.isAfter(start) || target.isAtSameMomentAs(start)) &&
          (target.isBefore(end) || target.isAtSameMomentAs(end))) {
        return timetable2;
      }
    }

    return null;
  }

  String _getSemesterNameForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    if (semester1Start != null && semester1End != null) {
      final start = DateTime(
        semester1Start!.year,
        semester1Start!.month,
        semester1Start!.day,
      );
      final end = DateTime(
        semester1End!.year,
        semester1End!.month,
        semester1End!.day,
      );
      if ((target.isAfter(start) || target.isAtSameMomentAs(start)) &&
          (target.isBefore(end) || target.isAtSameMomentAs(end))) {
        return '前期';
      }
    }

    if (semester2Start != null && semester2End != null) {
      final start = DateTime(
        semester2Start!.year,
        semester2Start!.month,
        semester2Start!.day,
      );
      final end = DateTime(
        semester2End!.year,
        semester2End!.month,
        semester2End!.day,
      );
      if ((target.isAfter(start) || target.isAtSameMomentAs(start)) &&
          (target.isBefore(end) || target.isAtSameMomentAs(end))) {
        return '後期';
      }
    }

    return '期間外';
  }

  @override
  void initState() {
    super.initState();
    _loadTasksFromHive();
  }

  // ★修正：従来のデータと新モデルデータを統合する関数
  void _loadTasksFromHive() {
    final box = Hive.box('tasks');

    // 💡 互換性対応：初めてプロファイル機能を使う場合、古いデータを「1年次」に自動移行する
    if (!box.containsKey('profiles_list')) {
      _profiles = ['1年次'];
      _currentProfile = '1年次';
      box.put('profiles_list', _profiles);
      box.put('current_profile_name', _currentProfile);

      if (box.containsKey('timetable1'))
        box.put('1年次_timetable1', box.get('timetable1'));
      if (box.containsKey('timetable2'))
        box.put('1年次_timetable2', box.get('timetable2'));
      if (box.containsKey('sem1_start'))
        box.put('1年次_sem1_start', box.get('sem1_start'));
      if (box.containsKey('sem1_end'))
        box.put('1年次_sem1_end', box.get('sem1_end'));
      if (box.containsKey('sem2_start'))
        box.put('1年次_sem2_start', box.get('sem2_start'));
      if (box.containsKey('sem2_end'))
        box.put('1年次_sem2_end', box.get('sem2_end'));
    } else {
      _profiles = List<String>.from(box.get('profiles_list'));
      _currentProfile =
          box.get('current_profile_name', defaultValue: _profiles.first)
              as String;
    }

    // 💡 現在選択されているプロファイル固有のデータを読み込む仕様に変更
    final savedTt1 = box.get('${_currentProfile}_timetable1');
    if (savedTt1 is List) {
      timetable1 = savedTt1
          .map((row) => List<String>.from(row as List))
          .toList();
    } else {
      timetable1 = List.generate(
        periods.length,
        (_) => List.generate(days.length, (_) => ''),
      );
    }

    final savedTt2 = box.get('${_currentProfile}_timetable2');
    if (savedTt2 is List) {
      timetable2 = savedTt2
          .map((row) => List<String>.from(row as List))
          .toList();
    } else {
      timetable2 = List.generate(
        periods.length,
        (_) => List.generate(days.length, (_) => ''),
      );
    }

    final s1StartStr = box.get('${_currentProfile}_sem1_start');
    final s1EndStr = box.get('${_currentProfile}_sem1_end');
    if (s1StartStr != null)
      semester1Start = DateTime.parse(s1StartStr);
    else
      semester1Start = null;
    if (s1EndStr != null)
      semester1End = DateTime.parse(s1EndStr);
    else
      semester1End = null;

    final s2StartStr = box.get('${_currentProfile}_sem2_start');
    final s2EndStr = box.get('${_currentProfile}_sem2_end');
    if (s2StartStr != null)
      semester2Start = DateTime.parse(s2StartStr);
    else
      semester2Start = null;
    if (s2EndStr != null)
      semester2End = DateTime.parse(s2EndStr);
    else
      semester2End = null;

    plainTasks.clear();
    periodTasks.clear();
    assignments.clear();

    // 1. 従来の 'tasks' ボックスから Map 形式データを読み込む
    for (var key in box.keys) {
      if (key is String) {
        if (key.endsWith('_plain')) {
          final dateKey = key.replaceAll('_plain', '');
          final dynamic savedData = box.get(key);
          if (savedData is List) {
            plainTasks[dateKey] = savedData
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        } else if (key.endsWith('_period')) {
          final dateKey = key.replaceAll('_period', '');
          final dynamic savedData = box.get(key);
          if (savedData is List) {
            periodTasks[dateKey] = savedData
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        }
      }
    }

    // 2. 新しい 'normalTasks' ボックスから NormalTask モデルデータを読み込んで統合
    final normalTasksBox = Hive.box<NormalTask>('normalTasks');
    for (var i = 0; i < normalTasksBox.length; i++) {
      final task = normalTasksBox.getAt(i);
      if (task != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(task.dueDate);
        final timeStr =
            '${task.dueDate.hour.toString().padLeft(2, '0')}:${task.dueDate.minute.toString().padLeft(2, '0')}';

        final taskMap = {
          'hiveKey': normalTasksBox.keyAt(i),
          'isNormalTaskModel': true,
          'text': task.title,
          'time': timeStr,
          'isCompleted': task.isCompleted,
          'description': task.description,
          'tag': task.tags.isNotEmpty ? task.tags.join(', ') : '',
          'periodIndex': task.collegeTime > 0 ? task.collegeTime - 1 : -1,
        };

        if (task.collegeTime > 0) {
          if (!periodTasks.containsKey(dateKey)) {
            periodTasks[dateKey] = [];
          }
          periodTasks[dateKey]!.add(taskMap);
        } else {
          if (!plainTasks.containsKey(dateKey)) {
            plainTasks[dateKey] = [];
          }
          plainTasks[dateKey]!.add(taskMap);
        }
      }
    }

    // assignments カレンダーマークを構築
    periodTasks.forEach((dateKey, tasks) {
      if (!assignments.containsKey(dateKey)) {
        assignments[dateKey] = List.generate(periods.length, (_) => '');
      }
      for (var task in tasks) {
        int pIdx = task['periodIndex'] as int? ?? -1;
        if (pIdx >= 0 && pIdx < periods.length) {
          assignments[dateKey]![pIdx] = 'has_task';
        }
      }
    });
    setState(() {});
  }

  // ★ カレンダーの上に表示する「今日のToDoリスト」ウィジェット
  Widget _buildTodayTodoWidget() {
    final today = DateTime.now();
    final String todayKey = DateFormat('yyyy-MM-dd').format(today);

    final allTodayPeriodTasks = periodTasks[todayKey] ?? [];
    final allTodayPlainTasks = plainTasks[todayKey] ?? [];

    final bool hasNoTasks =
        allTodayPeriodTasks.isEmpty && allTodayPlainTasks.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.deepPurple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '今日のToDoリスト (${DateFormat('M/d', 'ja').format(today)})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasNoTasks)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  '今日の予定はありません',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. 今日の時間割タスク
                    ...allTodayPeriodTasks.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final task = entry.value;
                      final isCompleted = task['isCompleted'] as bool? ?? false;
                      final pIdx = task['periodIndex'] as int? ?? -1;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isCompleted,
                                onChanged: (bool? value) async {
                                  if (task['isNormalTaskModel'] == true) {
                                    final normalBox = Hive.box<NormalTask>(
                                      'normalTasks',
                                    );
                                    final originalTask = normalBox.get(
                                      task['hiveKey'],
                                    );
                                    if (originalTask != null) {
                                      originalTask.isCompleted = value ?? false;
                                      await normalBox.put(
                                        task['hiveKey'],
                                        originalTask,
                                      );
                                    }
                                  } else {
                                    final box = Hive.box('tasks');
                                    final updated = Map<String, dynamic>.from(
                                      allTodayPeriodTasks[idx],
                                    );
                                    updated['isCompleted'] = value ?? false;
                                    periodTasks[todayKey]![idx] = updated;
                                    await box.put(
                                      '${todayKey}_period',
                                      periodTasks[todayKey],
                                    );
                                  }
                                  _loadTasksFromHive();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (pIdx != -1 ? '[${pIdx + 1}限] ' : '') +
                                    (task['text'] ?? ''),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isCompleted
                                      ? Colors.grey
                                      : Colors.black87,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // 2. 今日のその他のタスク
                    ...allTodayPlainTasks.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final task = entry.value;
                      final isCompleted = task['isCompleted'] as bool? ?? false;

                      final timeStr = task['time'] as String? ?? '';
                      final hasTime =
                          timeStr.isNotEmpty &&
                          timeStr != '00:00' &&
                          timeStr != '時刻未設定';
                      final displayPrefix = hasTime ? '[$timeStr] ' : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isCompleted,
                                onChanged: (bool? value) async {
                                  if (task['isNormalTaskModel'] == true) {
                                    final normalBox = Hive.box<NormalTask>(
                                      'normalTasks',
                                    );
                                    final originalTask = normalBox.get(
                                      task['hiveKey'],
                                    );
                                    if (originalTask != null) {
                                      originalTask.isCompleted = value ?? false;
                                      await normalBox.put(
                                        task['hiveKey'],
                                        originalTask,
                                      );
                                    }
                                  } else {
                                    final box = Hive.box('tasks');
                                    final updated = Map<String, dynamic>.from(
                                      allTodayPlainTasks[idx],
                                    );
                                    updated['isCompleted'] = value ?? false;
                                    plainTasks[todayKey]![idx] = updated;
                                    await box.put(
                                      '${todayKey}_plain',
                                      plainTasks[todayKey],
                                    );
                                  }
                                  _loadTasksFromHive();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayPrefix + (task['text'] ?? ''),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isCompleted
                                      ? Colors.grey
                                      : Colors.black87,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFabMenuItem(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    int? selectedDayIndex;
    String dateKey = '';
    if (_selectedDay != null) {
      int weekdayIndex = _selectedDay!.weekday - 1;
      if (weekdayIndex < 5) {
        selectedDayIndex = weekdayIndex;
      }
      dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    }

    final List<Widget> _tabs = [
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 240,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: ClockTimer(),
                ),
              ],
            ),
          ),

          _buildTodayTodoWidget(),

          TableCalendarSample(
            isWeekFormat: _isCalendarCollapsed,
            onFormatChanged: (isWeek) {
              setState(() {
                _isCalendarCollapsed = isWeek;
              });
            },
            onDayTapped: (selectedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _isCalendarCollapsed = true;
              });
            },
            assignments: assignments,
            plainTasks: plainTasks,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  top: 12.0,
                  left: 12.0,
                  right: 12.0,
                  bottom: 90.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: _selectedDay == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'カレンダーの日付をタップすると\nここにその日の時間割や予定が表示されます',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedDayIndex != null) ...[
                            Text(
                              '${days[selectedDayIndex]}曜日の時間割 (${_getSemesterNameForDate(_selectedDay!)})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (_getTimetableForDate(_selectedDay!) == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(
                                  child: Text(
                                    '設定された時間割の期間外です。',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(periods.length, (periodIndex) {
                                final currentTimetable = _getTimetableForDate(
                                  _selectedDay!,
                                )!;
                                final subject =
                                    currentTimetable[periodIndex][selectedDayIndex!];
                                final thisPeriodTasks =
                                    (periodTasks[dateKey] ?? [])
                                        .asMap()
                                        .entries
                                        .where(
                                          (entry) =>
                                              entry.value['periodIndex'] ==
                                              periodIndex,
                                        )
                                        .toList();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${periods[periodIndex]}限',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              subject.isEmpty
                                                  ? '（空きコマ）'
                                                  : subject,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: subject.isEmpty
                                                    ? Colors.grey
                                                    : Colors.black87,
                                                fontWeight: subject.isEmpty
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (thisPeriodTasks.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16.0,
                                            top: 4.0,
                                          ),
                                          child: Column(
                                            children: thisPeriodTasks.map((
                                              entry,
                                            ) {
                                              final globalIndex = entry.key;
                                              final task = entry.value;
                                              final isCompleted =
                                                  task['isCompleted']
                                                      as bool? ??
                                                  false;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2.0,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Checkbox(
                                                      value: isCompleted,
                                                      onChanged: (bool? value) async {
                                                        if (task['isNormalTaskModel'] ==
                                                            true) {
                                                          final normalBox =
                                                              Hive.box<
                                                                NormalTask
                                                              >('normalTasks');
                                                          final originalTask =
                                                              normalBox.get(
                                                                task['hiveKey'],
                                                              );
                                                          if (originalTask !=
                                                              null) {
                                                            originalTask
                                                                    .isCompleted =
                                                                value ?? false;
                                                            await normalBox.put(
                                                              task['hiveKey'],
                                                              originalTask,
                                                            );
                                                          }
                                                          _loadTasksFromHive();
                                                        } else {
                                                          final box = Hive.box(
                                                            'tasks',
                                                          );
                                                          setState(() {
                                                            final updatedTask =
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >.from(
                                                                  periodTasks[dateKey]![globalIndex],
                                                                );
                                                            updatedTask['isCompleted'] =
                                                                value ?? false;
                                                            periodTasks[dateKey]![globalIndex] =
                                                                updatedTask;
                                                          });
                                                          await box.put(
                                                            '${dateKey}_period',
                                                            periodTasks[dateKey],
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        task['text'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isCompleted
                                                              ? Colors.grey
                                                              : Colors
                                                                    .redAccent,
                                                          decoration:
                                                              isCompleted
                                                              ? TextDecoration
                                                                    .lineThrough
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.redAccent,
                                                        size: 20,
                                                      ),
                                                      onPressed: () async {
                                                        if (task['isNormalTaskModel'] ==
                                                            true) {
                                                          final normalBox =
                                                              Hive.box<
                                                                NormalTask
                                                              >('normalTasks');
                                                          await normalBox
                                                              .delete(
                                                                task['hiveKey'],
                                                              );
                                                          _loadTasksFromHive();
                                                        } else {
                                                          final box = Hive.box(
                                                            'tasks',
                                                          );
                                                          setState(() {
                                                            periodTasks[dateKey]!
                                                                .removeAt(
                                                                  globalIndex,
                                                                );
                                                            final hasMoreTasks =
                                                                periodTasks[dateKey]!.any(
                                                                  (t) =>
                                                                      t['periodIndex'] ==
                                                                      periodIndex,
                                                                );
                                                            if (!hasMoreTasks) {
                                                              assignments[dateKey]![periodIndex] =
                                                                  '';
                                                            }
                                                          });
                                                          await box.put(
                                                            '${dateKey}_period',
                                                            periodTasks[dateKey],
                                                          );
                                                          await box.put(
                                                            dateKey,
                                                            assignments[dateKey],
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                          ] else ...[
                            Text(
                              '${DateFormat('E', 'ja').format(_selectedDay!)}曜日は時間割の登録がありません',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],

                          if ((plainTasks[dateKey] ?? []).isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text(
                              'その他の予定・タスク',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...(plainTasks[dateKey] ?? []).asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final task = entry.value;
                              final isCompleted =
                                  task['isCompleted'] as bool? ?? false;
                              final timeStr = task['time'] as String? ?? '';
                              final hasTime =
                                  timeStr.isNotEmpty &&
                                  timeStr != '00:00' &&
                                  timeStr != '時刻未設定';

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isCompleted,
                                      onChanged: (bool? value) async {
                                        if (task['isNormalTaskModel'] == true) {
                                          final normalBox =
                                              Hive.box<NormalTask>(
                                                'normalTasks',
                                              );
                                          final originalTask = normalBox.get(
                                            task['hiveKey'],
                                          );
                                          if (originalTask != null) {
                                            originalTask.isCompleted =
                                                value ?? false;
                                            await normalBox.put(
                                              task['hiveKey'],
                                              originalTask,
                                            );
                                          }
                                          _loadTasksFromHive();
                                        } else {
                                          final box = Hive.box('tasks');
                                          setState(() {
                                            final updatedTask =
                                                Map<String, dynamic>.from(
                                                  plainTasks[dateKey]![index],
                                                );
                                            updatedTask['isCompleted'] =
                                                value ?? false;
                                            plainTasks[dateKey]![index] =
                                                updatedTask;
                                          });
                                          await box.put(
                                            '${dateKey}_plain',
                                            plainTasks[dateKey],
                                          );
                                        }
                                      },
                                    ),
                                    if (hasTime) ...[
                                      Container(
                                        width: 65,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? Colors.grey.shade200
                                              : Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isCompleted
                                                  ? Colors.grey
                                                  : Colors.deepPurple,
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],

                                    Expanded(
                                      child: Text(
                                        task['text'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted
                                              ? Colors.grey
                                              : Colors.black87,
                                          decoration: isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        if (task['isNormalTaskModel'] == true) {
                                          final normalBox =
                                              Hive.box<NormalTask>(
                                                'normalTasks',
                                              );
                                          await normalBox.delete(
                                            task['hiveKey'],
                                          );
                                          _loadTasksFromHive();
                                        } else {
                                          final box = Hive.box('tasks');
                                          setState(() {
                                            plainTasks[dateKey]!.removeAt(
                                              index,
                                            );
                                          });
                                          await box.put(
                                            '${dateKey}_plain',
                                            plainTasks[dateKey],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),

      // 💡 プロファイル管理に対応させた TimetableScreen
      TimetableScreen(
        timetable1: timetable1,
        timetable2: timetable2,
        semester1Start: semester1Start,
        semester1End: semester1End,
        semester2Start: semester2Start,
        semester2End: semester2End,

        // ✨ 追加したプロファイル用引数の受け渡しと各処理
        currentProfile: _currentProfile,
        profiles: _profiles,
        onProfileChanged: (newProfile) async {
          setState(() {
            _currentProfile = newProfile;
          });
          await Hive.box('tasks').put('current_profile_name', newProfile);
          _loadTasksFromHive(); // 切り替えたプロファイルの時間割データを再読込
        },
        onProfileAdded: (newProfileName) async {
          if (!_profiles.contains(newProfileName)) {
            setState(() {
              _profiles.add(newProfileName);
              _currentProfile = newProfileName;
            });
            final box = Hive.box('tasks');
            await box.put('profiles_list', _profiles);
            await box.put('current_profile_name', _currentProfile);

            // 新しいプロファイル用に、真っ白な時間割枠をHive上に初期化して即時保存
            final emptyTimetable = List.generate(
              periods.length,
              (_) => List.generate(days.length, (_) => ''),
            );
            await box.put('${newProfileName}_timetable1', emptyTimetable);
            await box.put('${newProfileName}_timetable2', emptyTimetable);

            _loadTasksFromHive();
          }
        },
        onProfileDeleted: (deletedProfileName) async {
          if (_profiles.length > 1) {
            setState(() {
              _profiles.remove(deletedProfileName);
              _currentProfile = _profiles.first; // 削除されたら一番最初のプロファイルに戻す
            });
            final box = Hive.box('tasks');
            await box.put('profiles_list', _profiles);
            await box.put('current_profile_name', _currentProfile);

            // 該当プロファイルの時間割・期間データを一括削除
            await box.delete('${deletedProfileName}_timetable1');
            await box.delete('${deletedProfileName}_timetable2');
            await box.delete('${deletedProfileName}_sem1_start');
            await box.delete('${deletedProfileName}_sem1_end');
            await box.delete('${deletedProfileName}_sem2_start');
            await box.delete('${deletedProfileName}_sem2_end');

            _loadTasksFromHive();
          }
        },
        onTimetable1Changed: (updated) async {
          setState(() => timetable1 = updated);
          await Hive.box('tasks').put(
            '${_currentProfile}_timetable1',
            updated.map((r) => r.toList()).toList(),
          );
        },
        onTimetable2Changed: (updated) async {
          setState(() => timetable2 = updated);
          await Hive.box('tasks').put(
            '${_currentProfile}_timetable2',
            updated.map((r) => r.toList()).toList(),
          );
        },
        onSemester1RangeChanged: (start, end) async {
          setState(() {
            semester1Start = start;
            semester1End = end;
          });
          await Hive.box(
            'tasks',
          ).put('${_currentProfile}_sem1_start', start?.toIso8601String());
          await Hive.box(
            'tasks',
          ).put('${_currentProfile}_sem1_end', end?.toIso8601String());
        },
        onSemester2RangeChanged: (start, end) async {
          setState(() {
            semester2Start = start;
            semester2End = end;
          });
          await Hive.box(
            'tasks',
          ).put('${_currentProfile}_sem2_start', start?.toIso8601String());
          await Hive.box(
            'tasks',
          ).put('${_currentProfile}_sem2_end', end?.toIso8601String());
        },
      ),

      const MyTabScreen(),
    ];

    return Scaffold(
      appBar: _currentIndex == 2
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: Text(_currentIndex == 0 ? widget.title : '時間割設定'),
            ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _tabs),
          if (_isFabExpanded) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isFabExpanded = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFabMenuItem('繰り返し予定を追加する', () {
                    setState(() => _isFabExpanded = false);
                  }),
                  const SizedBox(height: 12),
                  _buildFabMenuItem('予定を追加する', () async {
                    setState(() => _isFabExpanded = false);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEventScreen()),
                    );
                    if (result == true) {
                      _loadTasksFromHive();
                    }
                  }),
                  const SizedBox(height: 12),
                  _buildFabMenuItem('タスクを追加する', () {
                    setState(() => _isFabExpanded = false);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
              tooltip: 'メニューを開く',
              child: Icon(_isFabExpanded ? Icons.close : Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _isFabExpanded = false;
          });
          if (index == 0) {
            _loadTasksFromHive();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: '時間割'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'タスク一覧'),
        ],
      ),
    );
  }
}
