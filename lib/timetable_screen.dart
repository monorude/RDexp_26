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

    // ✨ プロファイル管理用の引数
    required this.currentProfile,
    required this.profiles,
    required this.onProfileChanged,
    required this.onProfileAdded,
    required this.onProfileDeleted,
  });

  final List<List<String>> timetable1;
  final List<List<String>> timetable2;
  final DateTime? semester1Start;
  final DateTime? semester1End;
  final DateTime? semester2Start;
  final DateTime? semester2End;

  final ValueChanged<List<List<String>>> onTimetable1Changed;
  final ValueChanged<List<List<String>>> onTimetable2Changed;
  final Function(DateTime? start, DateTime? end) onSemester1RangeChanged;
  final Function(DateTime? start, DateTime? end) onSemester2RangeChanged;

  // ✨ プロファイル管理用の型定義
  final String currentProfile;
  final List<String> profiles;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String> onProfileAdded;
  final ValueChanged<String> onProfileDeleted;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> days = ['月', '火', '水', '木', '金'];
  final List<String> periods = ['1', '2', '3', '4', '5'];

  int _editingSemester = 1;

  List<List<String>> get _currentTimetable {
    return _editingSemester == 1 ? widget.timetable1 : widget.timetable2;
  }

  String _formatRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '期限未設定（タップして設定）';
    final formatter = DateFormat('yyyy/MM/dd');
    return '${formatter.format(start)} 〜 ${formatter.format(end)}';
  }

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

  // ✨ 新しいプロファイルを作成するダイアログ
  void _showAddProfileDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新規プロファイルの作成'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(hintText: '例: 1年次、2年生など'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  widget.onProfileAdded(textController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );
  }

  // ✨ 現在のプロファイルを削除する確認ダイアログ
  void _showDeleteProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プロファイルの削除'),
          content: Text(
            '「${widget.currentProfile}」の時間割データを削除しますか？\nこの操作は取り消せません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.onProfileDeleted(widget.currentProfile);
                Navigator.pop(context);
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  void _editSubject(int periodIndex, int dayIndex) {
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
          // 💜 変更点：プロファイル管理バーを上品な薄紫ベースに変更
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 4.0,
              horizontal: 12.0,
            ),
            color: Colors.deepPurple.shade50, // ほんのり優しい薄紫
            child: Row(
              children: [
                Icon(
                  Icons.folder_shared,
                  color: Colors.deepPurple.shade700, // 落ち着いたディープパープル
                  size: 20,
                ),
                const SizedBox(width: 8),
                // プロファイル切り替えドロップダウン
                DropdownButton<String>(
                  value: widget.currentProfile,
                  underline: Container(), // 下線を消す
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.deepPurple.shade700,
                  ),
                  items: widget.profiles.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900, // 読みやすい濃い紫
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      widget.onProfileChanged(newValue);
                    }
                  },
                ),
                const Spacer(),
                // 新規作成ボタン
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Colors.deepPurple.shade700,
                  ),
                  onPressed: _showAddProfileDialog,
                  tooltip: '新しいプロファイルを作成',
                ),
                // 削除ボタン（危険操作のナビゲーションとして赤を維持）
                if (widget.profiles.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: _showDeleteProfileDialog,
                    tooltip: '現在のプロファイルを削除',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 前期・後期切り替え ＆ 期限設定を行うコントロールバー
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
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('前期'),
                      ),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      selected: _editingSemester == 1,
                      onSelected: (bool selected) {
                        if (selected) setState(() => _editingSemester = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('後期'),
                      ),
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                      // 💜 変更点：有効期間ボタンの文字と枠線をテーマカラーの紫に同調
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple.shade700,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.deepPurple.shade200),
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
                            final subject =
                                _currentTimetable[periodIndex][dayIndex];
                            return TableCell(
                              child: GestureDetector(
                                onTap: () =>
                                    _editSubject(periodIndex, dayIndex),
                                child: Container(
                                  height: 80,
                                  // 💜 変更点：入力済みセルの背景をほんのり薄紫（shade50）に
                                  color: subject.isEmpty
                                      ? Colors.white
                                      : Colors.deepPurple.shade50,
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
