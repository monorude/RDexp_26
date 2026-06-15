import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    required this.timetable1,
    required this.timetable2,
    required this.semester1Start,
    required this.semester1End,
    required this.semester2Start,
    required this.semester2End,
    required this.onTimetable1Changed,
    required this.onTimetable2Changed,
    required this.onSemester1RangeChanged,
    required this.onSemester2RangeChanged,
  });

  // ✨ 前期と後期のデータをそれぞれ受け取る
  final List<List<String>> timetable1;
  final List<List<String>> timetable2;

  // ✨ それぞれの期限データを受け取る
  final DateTime? semester1Start;
  final DateTime? semester1End;
  final DateTime? semester2Start;
  final DateTime? semester2End;

  // ✨ それぞれのデータが変更されたことを親(main.dart)に通知するコールバック
  final ValueChanged<List<List<String>>> onTimetable1Changed;
  final ValueChanged<List<List<String>>> onTimetable2Changed;
  final Function(DateTime? start, DateTime? end) onSemester1RangeChanged;
  final Function(DateTime? start, DateTime? end) onSemester2RangeChanged;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> days = ['月', '火', '水', '木', '金'];
  final List<String> periods = ['1', '2', '3', '4', '5'];

  // ✨ 現在この画面で「前期」「後期」のどちらを編集しているかを管理 (1: 前期, 2: 後期)
  int _editingSemester = 1;

  // ✨ 現在選択されている期の時間割データを取得するヘルパー
  List<List<String>> get _currentTimetable {
    return _editingSemester == 1 ? widget.timetable1 : widget.timetable2;
  }

  // ✨ 期限表示用のフォーマット関数
  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '期限未設定（タップして設定）';
    final formatter = DateFormat('yyyy/MM/dd');
    return '${formatter.format(start)} 〜 ${formatter.format(end)}';
  }

  // ✨ 日付の範囲選択（カレンダーピッカー）を開く
  Future<void> _selectSemesterRange() async {
    DateTimeRange? initialRange;
    if (_editingSemester == 1 &&
        widget.semester1Start != null &&
        widget.semester1End != null) {
      initialRange = DateTimeRange(
        start: widget.semester1Start!,
        end: widget.semester1End!,
      );
    } else if (_editingSemester == 2 &&
        widget.semester2Start != null &&
        widget.semester2End != null) {
      initialRange = DateTimeRange(
        start: widget.semester2Start!,
        end: widget.semester2End!,
      );
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: _editingSemester == 1 ? '前期の有効期間を選択' : '後期の有効期間を選択',
    );

    if (picked != null) {
      if (_editingSemester == 1) {
        widget.onSemester1RangeChanged(picked.start, picked.end);
      } else {
        widget.onSemester2RangeChanged(picked.start, picked.end);
      }
    }
  }

  void _editSubject(int periodIndex, int dayIndex) {
    // ✨ 選択中の時間割から科目名を取得
    final textController = TextEditingController(
      text: _currentTimetable[periodIndex][dayIndex],
    );

    showDialog(
      context: context,
      builder: (context) {
        final semesterName = _editingSemester == 1 ? '前期' : '後期';
        return AlertDialog(
          title: Text(
            '[$semesterName] ${days[dayIndex]}曜日 ${periods[periodIndex]}限の科目',
          ),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(hintText: '科目名を入力'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                // ✨ 選択中の時間割の複製を作って更新し、対応するコールバックを呼ぶ
                List<List<String>> newTimetable = _currentTimetable
                    .map((row) => List<String>.from(row))
                    .toList();
                newTimetable[periodIndex][dayIndex] = textController.text;

                if (_editingSemester == 1) {
                  widget.onTimetable1Changed(newTimetable);
                } else {
                  widget.onTimetable2Changed(newTimetable);
                }

                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ✨ 【追加】前期・後期切り替え ＆ 期限設定を行うコントロールバー
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('前期'),
                      selected: _editingSemester == 1,
                      onSelected: (bool selected) {
                        if (selected) setState(() => _editingSemester = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('後期'),
                      selected: _editingSemester == 2,
                      onSelected: (bool selected) {
                        if (selected) setState(() => _editingSemester = 2);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _selectSemesterRange,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _editingSemester == 1
                            ? _formatRange(
                                widget.semester1Start,
                                widget.semester1End,
                              )
                            : _formatRange(
                                widget.semester2Start,
                                widget.semester2End,
                              ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.blueAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 時間割テーブル表示エリア
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1.0),
                    1: FlexColumnWidth(2.0),
                    2: FlexColumnWidth(2.0),
                    3: FlexColumnWidth(2.0),
                    4: FlexColumnWidth(2.0),
                    5: FlexColumnWidth(2.0),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        const TableCell(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(''),
                            ),
                          ),
                        ),
                        ...days.map(
                          (day) => TableCell(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...List.generate(periods.length, (periodIndex) {
                      return TableRow(
                        children: [
                          TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Container(
                              height: 80,
                              color: Colors.grey.shade50,
                              child: Center(
                                child: Text(
                                  '${periods[periodIndex]}限',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ...List.generate(days.length, (dayIndex) {
                            // ✨ 選択中の時間割（前期 or 後期）から科目名を表示
                            final subject =
                                _currentTimetable[periodIndex][dayIndex];
                            return TableCell(
                              child: GestureDetector(
                                onTap: () =>
                                    _editSubject(periodIndex, dayIndex),
                                child: Container(
                                  height: 80,
                                  color: subject.isEmpty
                                      ? Colors.white
                                      : Colors.blue.shade50,
                                  padding: const EdgeInsets.all(4.0),
                                  child: Center(
                                    child: Text(
                                      subject,
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
