import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TableCalendarSample extends StatefulWidget {
  const TableCalendarSample({
    super.key,
    required this.onDayTapped,
    required this.assignments,
  });

  final ValueChanged<DateTime> onDayTapped;
  final Map<String, List<String>> assignments;

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

      // カレンダーの日付ごとに表示するイベント（予定）を読み込む
      eventLoader: (day) {
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final dayEvents = widget.assignments[dateKey];

        if (dayEvents != null) {
          // 空欄じゃない予定だけをリストにして返す
          return dayEvents.where((event) => event.isNotEmpty).toList();
        }
        return [];
      },

      // カレンダーの見た目と「表示個数」のカスタム設定
      calendarStyle: const CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Colors.redAccent, // 🔴 点の色を赤にする
          shape: BoxShape.circle,
        ),
        // 🌟 順番を正しく修正しました！これでリミッターが5個になります
        markersMaxCount: 5,
      ),

      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });

        // 実際にタップされた日付（selectedDay）を親に渡す
        widget.onDayTapped(selectedDay);
      },
    );
  }
}
