import 'dart:async';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('tasks'); // ← 課題保存用 Box
  Hive.registerAdapter(NormalTaskAdapter());
  await Hive.openBox<NormalTask>('normalTasks');

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'hoge'),
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
  int _notificationId = 0;

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

  void _addNewAssignment(
    String dateKey,
    int? periodIndex,
    String text,
    TimeOfDay? time,
    String subjectName,
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

  // 前期と後期の時間割データ
  late List<List<String>> timetable1;
  late List<List<String>> timetable2;

  // それぞれの時間割の期限（開始日・終了日）
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

  // 日付から所属する期の名前を取得する（UI表示用）
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
    _loadTasksFromHive(); // 初期化時にHiveからデータを読み込む
  }

  // ★追加：Hiveからタスクデータを最新状態に再読み込みする関数
  void _loadTasksFromHive() {
    final box = Hive.box('tasks');

    // 前期・後期の時間割データをそれぞれHiveから読み込み
    final savedTt1 = box.get('timetable1');
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

    final savedTt2 = box.get('timetable2');
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

    // 前期・後期の期限データを読み込み
    final s1StartStr = box.get('sem1_start');
    final s1EndStr = box.get('sem1_end');
    if (s1StartStr != null) semester1Start = DateTime.parse(s1StartStr);
    if (s1EndStr != null) semester1End = DateTime.parse(s1EndStr);

    final s2StartStr = box.get('sem2_start');
    final s2EndStr = box.get('sem2_end');
    if (s2StartStr != null) semester2Start = DateTime.parse(s2StartStr);
    if (s2EndStr != null) semester2End = DateTime.parse(s2EndStr);

    // 再読み込み時の重複を防ぐために一度クリアする
    plainTasks.clear();
    periodTasks.clear();
    assignments.clear();

    // タスクデータの読み込み
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

    // カレンダーマーカーの同期
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

    setState(() {}); // 読み込み後に画面を再描画する
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
      // 【タブ1: ホーム（カレンダーと日課表示）】
      Column(
        children: [
          Center(
            child: Container(
              width: 288,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: ClockTimer(),
            ),
          ),
          TableCalendarSample(
            onDayTapped: (selectedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
            assignments: assignments,
            plainTasks: plainTasks,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
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

                          // その他の予定・タスクは曜日・期間を問わず独立して表示
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

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isCompleted,
                                      onChanged: (bool? value) async {
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
                                      },
                                    ),
                                    Container(
                                      width: 65,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? Colors.grey.shade200
                                            : Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Text(
                                          task['time'] ?? '時刻未設定',
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
                                        final box = Hive.box('tasks');
                                        setState(() {
                                          plainTasks[dateKey]!.removeAt(index);
                                        });
                                        await box.put(
                                          '${dateKey}_plain',
                                          plainTasks[dateKey],
                                        );
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

      // 【タブ2: 時間割設定画面】
      TimetableScreen(
        timetable1: timetable1,
        timetable2: timetable2,
        semester1Start: semester1Start,
        semester1End: semester1End,
        semester2Start: semester2Start,
        semester2End: semester2End,
        onTimetable1Changed: (updated) async {
          setState(() => timetable1 = updated);
          await Hive.box(
            'tasks',
          ).put('timetable1', updated.map((r) => r.toList()).toList());
        },
        onTimetable2Changed: (updated) async {
          setState(() => timetable2 = updated);
          await Hive.box(
            'tasks',
          ).put('timetable2', updated.map((r) => r.toList()).toList());
        },
        onSemester1RangeChanged: (start, end) async {
          setState(() {
            semester1Start = start;
            semester1End = end;
          });
          await Hive.box('tasks').put('sem1_start', start?.toIso8601String());
          await Hive.box('tasks').put('sem1_end', end?.toIso8601String());
        },
        onSemester2RangeChanged: (start, end) async {
          setState(() {
            semester2Start = start;
            semester2End = end;
          });
          await Hive.box('tasks').put('sem2_start', start?.toIso8601String());
          await Hive.box('tasks').put('sem2_end', end?.toIso8601String());
        },
      ),

      // タブ3: タスク一覧画面
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
      body: IndexedStack(index: _currentIndex, children: _tabs),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEventScreen()),
                );
                if (result != null && result is Map<String, dynamic>) {
                  final text = result['text'] as String;
                  final periodIndex = result['periodIndex'] as int?;
                  final time = result['time'] as TimeOfDay?;
                  final DateTime selectedDate = result['date'] as DateTime;
                  final String targetDateKey = DateFormat(
                    'yyyy-MM-dd',
                  ).format(selectedDate);
                  int weekdayIndex = selectedDate.weekday - 1;
                  if (weekdayIndex > 4) weekdayIndex = 0;
                  final currentTimetable = _getTimetableForDate(
                    selectedDate,
                  );
                  final subject =
                      (periodIndex != null &&
                          periodIndex != -1 &&
                          currentTimetable != null)
                      ? currentTimetable[periodIndex][weekdayIndex]
                      : '';
                  _addNewAssignment(
                    targetDateKey,
                    periodIndex,
                    text,
                    time,
                    subject,
                  );
                }
              },
              tooltip: '予定を追加する',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // ★修正：ホームタブ（0番目）に戻ったとき、Hiveデータを再ロードしてカレンダー側を最新に同期する
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
