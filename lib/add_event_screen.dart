import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'NormalTask.dart';
import 'period_time_store.dart';

/// NormalTask モデルに基づいて予定情報を入力・登録するための画面
class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});
  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  late Box<NormalTask> _box;

  // 自由記述フォームのコントローラー
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 日付・時刻の入力状態
  DateTime? _selectedDate;

  // _selectedTime は手動入力または時限から導出された実効時刻を保持する
  TimeOfDay? _selectedTime;

  // true のとき、_selectedTime はユーザーが直接選択した値であり時限ドロップダウンを無効化する
  bool _isManualTime = false;

  // null: 未選択、1〜5: 各時限
  int? _selectedPeriod;

  // タグ管理
  String? _selectedTag;

  // タグ一覧の読み込み処理（Hive Box などからの取得）はここに記述する
  final List<String> _availableTags = [];

  // 時限ごとの授業開始時刻（PeriodTimeStore から initState で読み込む）
  late Map<int, TimeOfDay> _periodTimes;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<NormalTask>('normalTasks');
    _periodTimes = {for (var i = 1; i <= 5; i++) i: PeriodTimeStore.getTime(i)};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 日付選択ダイアログを開く
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;

        // 土曜日または日曜日が選択された場合、時限の選択を強制クリアする
        if (picked.weekday == DateTime.saturday ||
            picked.weekday == DateTime.sunday) {
          _selectedPeriod = null;
          // 時限由来の自動入力時刻が入っていた場合はそれもクリアする（手動入力時刻は残す）
          if (!_isManualTime) {
            _selectedTime = null;
          }
        }
      });
    }
  }

  // 時刻選択ダイアログを開く
  // 手動入力として扱われ、時限の選択が解除・無効化される
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _isManualTime = true;
        // 手動で時刻を入力した場合、時限の選択は無意味になるため解除する
        _selectedPeriod = null;
      });
    }
  }

  // 手動入力した時刻をクリアし、時限の選択を再び有効にする
  void _clearTime() {
    setState(() {
      _selectedTime = null;
      _isManualTime = false;
    });
  }

  // 時限が選択されたとき、対応する開始時刻で _selectedTime を上書きする
  void _onPeriodChanged(int? period) {
    setState(() {
      _selectedPeriod = period;
      if (period != null) {
        _selectedTime = _periodTimes[period];
        _isManualTime = false;
      } else {
        // 未選択に戻した場合は時刻もクリアする
        _selectedTime = null;
      }
    });
  }

  // 🌟 手動で時刻が入力された場合、どの時限のコマに割り振るかを自動判定するヘルパー関数
  int _determinePeriod(TimeOfDay? time) {
    if (time == null) return 1; // 未選択ならデフォルト1限
    final minutes = time.hour * 60 + time.minute;

    if (minutes >= 17 * 60 + 15) return 5; // 17:15以降は5限
    if (minutes >= 15 * 60 + 30) return 4; // 15:30以降は4限
    if (minutes >= 13 * 60 + 45) return 3; // 13:45以降は3限
    if (minutes >= 11 * 60 + 5) return 2; // 11:05以降は2限
    return 1; // それ以前は1限
  }

  // タグ作成ダイアログを表示し、入力されたタグをリストに追加する
  void _showCreateTagDialog() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タグを作成'),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: 'タグ名を入力',
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
              final tagName = tagController.text.trim();
              if (tagName.isNotEmpty && !_availableTags.contains(tagName)) {
                setState(() {
                  _availableTags.add(tagName);
                  _selectedTag = tagName;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  // 入力内容を検証し、問題があればエラーメッセージを返す（正常なら null を返す）
  String? _validate() {
    if (_titleController.text.trim().isEmpty) {
      return 'タイトルを入力してください';
    }
    if (_titleController.text.contains(RegExp(r'[\\/:*?"<>|]')) ||
        _descriptionController.text.contains(RegExp(r'[\\/:*?"<>|]'))) {
      return '使用できない文字が含まれています';
    }
    if (_selectedDate == null) {
      return '開始日を選択してください';
    }
    return null;
  }

  // 登録ボタン押下時の処理：検証・整形を行いタスクオブジェクトを構築する
  Future<void> _onSubmit() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // 時刻が未入力の場合は 0:00 として扱う
    final effectiveTime = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0);
    final dueDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      effectiveTime.hour,
      effectiveTime.minute,
    );

    // 入力内容を NormalTask に整形する
    final task = NormalTask(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: dueDate,
      isCompleted: false,
      tag: _selectedTag ?? '',
      collegeTime: _selectedPeriod ?? 0,
    );

    await _box.add(task);

    if (!mounted) return;
    // 🌟 時限（1〜5）を確定させ、0から始まるインデックス（0〜4）に変換する
    final periodIndex = _selectedPeriod != null ? _selectedPeriod! - 1 : -1;

    // 🌟 データを Map に詰めて、Navigator.pop で main.dart に返却する
    Navigator.pop(context, {
      'text': _titleController.text.trim(),
      'periodIndex': periodIndex,
      'time': _selectedTime,
      'date': _selectedDate,
    });
  }

  // TimeOfDay を "HH:MM" 形式の文字列に変換する
  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // DateTime を "YYYY/MM/DD" 形式の文字列に変換する
  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    // 土曜日(6)または日曜日(7)が選択されているか判定
    final bool isWeekend =
        _selectedDate != null &&
        (_selectedDate!.weekday == DateTime.saturday ||
            _selectedDate!.weekday == DateTime.sunday);

    // 手動入力中、または土日の場合は時限ドロップダウンを無効化（グレーアウト）する
    final bool isPeriodDisabled = _isManualTime || isWeekend;

    return Scaffold(
      appBar: AppBar(title: const Text('予定を追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル入力
            const Text('タイトル', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'タイトルを入力',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 説明入力
            const Text('説明', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: '説明を入力（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 3,
            ),
            const SizedBox(height: 20),

            // 開始日選択
            const Text('開始日', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                _selectedDate != null ? _formatDate(_selectedDate!) : '日付を選択',
              ),
            ),
            const SizedBox(height: 20),

            // 開始時刻と時限
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '開始時刻',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              _selectedTime != null
                                  ? _formatTime(_selectedTime!)
                                  : '未選択',
                            ),
                          ),
                          if (_isManualTime) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: '時刻をクリアして時限の選択を再び有効にする',
                              onPressed: _clearTime,
                            ),
                          ],
                        ],
                      ),
                      // ✨【修正】手動入力中の警告のみ残し、土日の警告テキストの条件分岐を削除しました
                      if (_isManualTime)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '手動入力中は時限を選択できません',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 時限選択ドロップダウン
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '時限',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPeriodDisabled
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int?>(
                        value: _selectedPeriod,
                        isExpanded: true,
                        onChanged: isPeriodDisabled ? null : _onPeriodChanged,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('未選択'),
                          ),
                          ...List.generate(5, (i) => i + 1).map(
                            (period) => DropdownMenuItem<int?>(
                              value: period,
                              child: Text('$period 限'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // タグ管理フォーム
            const Text('タグ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _availableTags.isEmpty
                          ? const SizedBox(
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'タグがありません。作成ボタンから追加してください',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              children: _availableTags.map((tag) {
                                final isSelected = _selectedTag == tag;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(tag),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedTag = isSelected ? null : tag;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _showCreateTagDialog,
                    child: const Text('作成'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 登録ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('登録', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
