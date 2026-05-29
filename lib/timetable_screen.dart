import 'package:flutter/material.dart';

class TimetableScreen extends StatefulWidget {
  // 親からデータと通知関数を受け取るための引数を定義
  const TimetableScreen({
    super.key,
    required this.timetable,
    required this.onTimetableChanged,
  });

  final List<List<String>> timetable;
  final ValueChanged<List<List<String>>> onTimetableChanged;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> days = ['月', '火', '水', '木', '金'];
  final List<String> periods = ['1', '2', '3', '4', '5'];

  void _editSubject(int periodIndex, int dayIndex) {
    final textController = TextEditingController(
      text: widget.timetable[periodIndex][dayIndex],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${days[dayIndex]}曜日 ${periods[periodIndex]}限の科目'),
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
                List<List<String>> newTimetable = List.from(widget.timetable);
                newTimetable[periodIndex][dayIndex] = textController.text;

                // 親に「変更されたデータ」を報告
                widget.onTimetableChanged(newTimetable);

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
      appBar: AppBar(
        title: const Text('時間割設定'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Container(
                        height: 80,
                        color: Colors.grey.shade50,
                        child: Center(
                          child: Text(
                            '${periods[periodIndex]}限',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    ...List.generate(days.length, (dayIndex) {
                      final subject = widget.timetable[periodIndex][dayIndex];
                      return TableCell(
                        child: GestureDetector(
                          onTap: () => _editSubject(periodIndex, dayIndex),
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
    );
  }
}
