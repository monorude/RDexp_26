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

void main() {
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  bool _isFabExpanded = false;

  final List<String> days = ['月', '火', '水', '木', '金'];
  final List<String> periods = ['1', '2', '3', '4', '5'];
  late List<List<String>> timetable;

  DateTime? _selectedDay;

  Map<String, List<String>> assignments = {};

  @override
  void initState() {
    super.initState();
    timetable = List.generate(
      periods.length,
      (_) => List.generate(days.length, (_) => ''),
    );
  }

  void _editAssignment(String dateKey, int periodIndex, String subjectName) {
    String currentAssignment = '';
    if (assignments.containsKey(dateKey)) {
      currentAssignment = assignments[dateKey]![periodIndex];
    }

    final textController = TextEditingController(text: currentAssignment);
    final displaySubject = subjectName.isEmpty ? '空きコマ' : subjectName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$displaySubject (${periods[periodIndex]}限) の予定・課題'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: '課題、テスト、持ち物などを入力',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (!assignments.containsKey(dateKey)) {
                    assignments[dateKey] = List.generate(
                      periods.length,
                      (_) => '',
                    );
                  }
                  assignments[dateKey]![periodIndex] = textController.text;
                });
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFabMenuItem(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 6,
      ),
      child: Text(label),
    );
  }

  String getTodayDate() {
    initializeDateFormatting('ja');
    return DateFormat.yMMMMEEEEd('ja').format(DateTime.now()).toString();
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
                child: selectedDayIndex == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'カレンダーの日付（月〜金）をタップすると\nここにその日の時間割が表示されます',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${days[selectedDayIndex]}曜日の時間割 (タップして予定を追加)',
                            //(textに絵文字を含めると表示が崩れるため修正 dev-mono-4)
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(periods.length, (periodIndex) {
                            final subject =
                                timetable[periodIndex][selectedDayIndex!];
                            final assignment =
                                (assignments.containsKey(dateKey))
                                ? assignments[dateKey]![periodIndex]
                                : '';

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _editAssignment(dateKey, periodIndex, subject);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
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
                                          if (assignment.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '予定: $assignment',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),

      TimetableScreen(
        timetable: timetable,
        onTimetableChanged: (updatedTimetable) {
          setState(() {
            timetable = updatedTimetable;
          });
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
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
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
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
                  _buildFabMenuItem('予定を追加する', () {
                    setState(() => _isFabExpanded = false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEventScreen(),
                      ),
                    );
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
              onPressed: () =>
                  setState(() => _isFabExpanded = !_isFabExpanded),
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
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: '時間割'),
        ],
      ),
    );
  }
}
