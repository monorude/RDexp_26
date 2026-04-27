import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class TableCalendarSample extends StatelessWidget {
  const TableCalendarSample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 1, 1),
        focusedDay: DateTime.now(),
     ),
    );
  }
}