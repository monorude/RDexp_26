import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TableCalendarSample extends StatefulWidget {
  const TableCalendarSample({
    super.key,
    required this.onDayTapped,
    required this.assignments,
    required this.plainTasks, // 時限なしタスクを受け取る引数を追加
  });

  final ValueChanged<DateTime> onDayTapped;
  final Map<String, List<String>> assignments;
  final Map<String, List<Map<String, dynamic>>> plainTasks; // 型を追加

  @override
  State<TableCalendarSample> createState() => _TableCalendarSampleState();
}

class _TableCalendarSampleState extends State<TableCalendarSample> {
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 1, 1),
      lastDay: DateTime.utc(2030, 1, 1),
      focusedDay: _focusedDay,
      locale: 'ja_JP',

      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },

      // eventLoaderを修正して、両方の予定を合算する
      eventLoader: (day) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);

        // ① 時限あり予定（空文字を除外）
        final dayEvents = widget.assignments[dateKey] ?? [];
        final filteredEvents = dayEvents
            .where((event) => event.isNotEmpty)
            .toList();

        // ② 時限なしタスク（textを取り出して空文字を除外）
        final dayPlainTasks = widget.plainTasks[dateKey] ?? [];
        final filteredTasks = dayPlainTasks
            .map((task) => task['text'] as String? ?? '')
            .where((text) => text.isNotEmpty)
            .toList();

        // ③ 両方を合わせたリストを返す（これでどちらに予定があってもドットが出ます）
        return [...filteredEvents, ...filteredTasks];
      },

      calendarStyle: const CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 5,
      ),

      availableGestures: AvailableGestures.horizontalSwipe,

      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });

        widget.onDayTapped(selectedDay);
      },
    );
  }
}
