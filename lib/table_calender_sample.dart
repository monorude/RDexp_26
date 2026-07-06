import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TableCalendarSample extends StatefulWidget {
  const TableCalendarSample({
    super.key,
    required this.onDayTapped,
    required this.assignments,
    required this.plainTasks,
    required this.isWeekFormat,
    required this.onFormatChanged,
  });

  final ValueChanged<DateTime> onDayTapped;
  final Map<String, List<String>> assignments;
  final Map<String, List<Map<String, dynamic>>> plainTasks;
  final bool isWeekFormat;
  final ValueChanged<bool> onFormatChanged;

  @override
  State<TableCalendarSample> createState() => _TableCalendarSampleState();
}

class _TableCalendarSampleState extends State<TableCalendarSample> {
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 💡 自作のカスタムヘッダー（左側に年月・矢印、右側にアクションボタン群を配置）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              // 前の月/週へ移動する矢印
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (widget.isWeekFormat) {
                      _focusedDay = _focusedDay.subtract(
                        const Duration(days: 7),
                      );
                    } else {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month - 1,
                        1,
                      );
                    }
                  });
                },
              ),
              // ○○○○年○月 のテキスト
              Text(
                DateFormat('yyyy年M月', 'ja_JP').format(_focusedDay),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 次の月/週へ移動する矢印
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    if (widget.isWeekFormat) {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    } else {
                      _focusedDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month + 1,
                        1,
                      );
                    }
                  });
                },
              ),

              const Spacer(), // 👈 これで左側のナビゲーションと右側のボタンを綺麗に両端に離します
              // ✨ 新設：今日の日付にジャンプするボタン
              OutlinedButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    _focusedDay = now; // カレンダーの表示を今月に戻す
                    _selectedDay = now; // 今日を選択状態にする
                  });
                  widget.onDayTapped(now); // 親（main.dart）にも通知して画面下のタスクを今日に切り替える
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 32), // 高さを揃える
                ),
                child: const Text(
                  '今日',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 8), // ボタン同士のすき間
              // 💡 既存：週表示 / 月表示 の切り替えボタン
              OutlinedButton(
                onPressed: () {
                  widget.onFormatChanged(!widget.isWeekFormat);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  widget.isWeekFormat ? '月表示にする' : '週表示にする',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // カレンダー本体
        TableCalendar(
          firstDay: DateTime.utc(2010, 1, 1),
          lastDay: DateTime.utc(2030, 1, 1),
          focusedDay: _focusedDay,
          locale: 'ja_JP',
          headerVisible: false, // ✨ 自作ヘッダーを使うため、元のヘッダーは非表示にする

          calendarFormat: widget.isWeekFormat
              ? CalendarFormat.week
              : CalendarFormat.month,

          // 左右スワイプで月を切り替えたとき、自作ヘッダーの年月も自動で連動させる設定
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },

          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },

          eventLoader: (day) {
            final dateKey = DateFormat('yyyy-MM-dd').format(day);

            final dayEvents = widget.assignments[dateKey] ?? [];
            final filteredEvents = dayEvents
                .where((event) => event.isNotEmpty)
                .toList();

            final dayPlainTasks = widget.plainTasks[dateKey] ?? [];
            final filteredTasks = dayPlainTasks
                .map((task) => task['text'] as String? ?? '')
                .where((text) => text.isNotEmpty)
                .toList();

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
        ),
      ],
    );
  }
}
