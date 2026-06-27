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

  // null: 未選択、1から5: 各時限
  int? _selectedPeriod;

  // タグ管理
  final List<String> _selectedTags = []; // 複数選択用のリスト

  // タグ一覧の読み込み処理（Hive Box などからの取得）はここに記述する
  final List<String> _availableTags = [];

  // 時限ごとの授業開始時刻（PeriodTimeStore から initState で読み込む）
  late Map<int, TimeOfDay> _periodTimes;

  // 繰り返し設定パネルの開閉状態
  bool _isRepeatExpanded = false;

  // 繰り返し期間：週・隔週・月（null は「なし」=繰り返しなし）
  String? _repeatInterval;

  // 繰り返し期限：月・年・前期・後期（null は「なし」）
  String? _repeatEndType;

  // 非通知設定（true の場合、登録時に非通知フラグをオンにする）
  bool _isMuted = false;

  // 繰り返し期間の選択肢
  static const List<String> _repeatIntervalOptions = ['週', '隔週', '月'];

  // 繰り返し期限の選択肢
  static const List<String> _repeatEndTypeOptions = ['月', '年', '前期', '後期'];

  // 繰り返し設定が登録されているか（繰り返し期間が選択されていれば true）
  bool get _hasRepeatSettings => _repeatInterval != null;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<NormalTask>('normalTasks');
    _periodTimes = {for (var i = 1; i <= 5; i++) i: PeriodTimeStore.getTime(i)};

    final taskBox = Hive.box('tasks');
    final savedTags = taskBox.get('available_tags');
    if (savedTags is List) {
      _availableTags.addAll(List<String>.from(savedTags));
    }
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
            onPressed: () async {
              final tagName = tagController.text.trim();
              if (tagName.isNotEmpty && !_availableTags.contains(tagName)) {
                setState(() {
                  _availableTags.add(tagName);
                  _selectedTags.add(tagName); // 作成したタグを選択状態に追加
                });

                final taskBox = Hive.box('tasks');
                await taskBox.put('available_tags', _availableTags);
              }
              Navigator.pop(context);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  // 入力内容を検証
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

  // 🛠 変更箇所：繰り返し期限（EndType）から具体的な最終終了日を計算するヘルパー
  DateTime _calculateEndDate(DateTime startDate, String? endType) {
    if (endType == null) {
      // 期限の指定がない場合は、暫定的に開始日の3ヶ月後を期限にする（無限ループ防止）
      return startDate.add(const Duration(days: 90));
    }

    // 時間割や期間が保存されているHive Boxを開く
    final taskBox = Hive.box('tasks');

    switch (endType) {
      case '月':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case '年':
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
      case '前期':
        final savedSem1End = taskBox.get('sem1_end');
        if (savedSem1End != null) {
          // 保存形式が String の場合はパースし、DateTime の場合はそのまま利用する
          return savedSem1End is DateTime
              ? savedSem1End
              : DateTime.parse(savedSem1End.toString());
        }
        // 設定データがない場合のフォールバック（元のロジック）
        int targetYear = startDate.year;
        if (startDate.month >= 10) targetYear += 1;
        return DateTime(targetYear, 9, 30, 23, 59);

      case '後期':
        final savedSem2End = taskBox.get('sem2_end');
        if (savedSem2End != null) {
          // 保存形式が String の場合はパースし、DateTime の場合はそのまま利用する
          return savedSem2End is DateTime
              ? savedSem2End
              : DateTime.parse(savedSem2End.toString());
        }
        // 設定データがない場合のフォールバック（元のロジック）
        int targetYear = startDate.year;
        if (startDate.month >= 4) targetYear += 1;
        return DateTime(targetYear, 3, 31, 23, 59);

      default:
        return startDate;
    }
  }

  // 31日問題を考慮した月加算ロジックを含む次の予定日計算
  DateTime _getNextDueDate(DateTime current, String interval) {
    switch (interval) {
      case '週':
        return current.add(const Duration(days: 7));
      case '隔週':
        return current.add(const Duration(days: 14));
      case '月':
        final nextMonth = current.month + 1;
        final nextYear = current.year + (nextMonth > 12 ? 1 : 0);
        final targetMonth = nextMonth > 12 ? 1 : nextMonth;

        // 翌月の末日を確認するために、翌々月の0日（＝翌月末日）を取得
        final lastDayOfNextMonth = DateTime(nextYear, targetMonth + 1, 0).day;
        final targetDay = current.day > lastDayOfNextMonth
            ? lastDayOfNextMonth
            : current.day;

        return DateTime(
          nextYear,
          targetMonth,
          targetDay,
          current.hour,
          current.minute,
        );
      default:
        return current.add(const Duration(days: 7));
    }
  }

  // 登録ボタン押下時の処理
  Future<void> _onSubmit() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final effectiveTime = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0);
    final baseDueDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      effectiveTime.hour,
      effectiveTime.minute,
    );

    if (_hasRepeatSettings && _repeatInterval != null) {
      final endDate = _calculateEndDate(baseDueDate, _repeatEndType);
      DateTime currentDueDate = baseDueDate;

      while (currentDueDate.isBefore(endDate) ||
          currentDueDate.isAtSameMomentAs(endDate)) {
        final task = NormalTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          dueDate: currentDueDate,
          isCompleted: false,
          tags: List<String>.from(_selectedTags), // リストのコピーを渡してメモリ参照を分離
          collegeTime: _selectedPeriod ?? 0,
          repeatInterval: _repeatInterval,
          repeatEndType: _repeatEndType,
          isMuted: _isMuted,
        );

        await _box.add(task);
        currentDueDate = _getNextDueDate(currentDueDate, _repeatInterval!);
      }
    } else {
      final task = NormalTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: baseDueDate,
        isCompleted: false,
        tags: List<String>.from(_selectedTags), // ここも参照を分離
        collegeTime: _selectedPeriod ?? 0,
        repeatInterval: _repeatInterval,
        repeatEndType: _repeatEndType,
        isMuted: _isMuted,
      );

      await _box.add(task);
    }

    if (!mounted) return;

    // 呼び出し元に「登録が完了したこと(true)」を伝えて画面を戻します。
    Navigator.pop(context, true);
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeekend =
        _selectedDate != null &&
        (_selectedDate!.weekday == DateTime.saturday ||
            _selectedDate!.weekday == DateTime.sunday);

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
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 20),

            // 開始日選択・繰り返し設定
            const Text('開始日', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : '日付を選択',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isRepeatExpanded = !_isRepeatExpanded);
                  },
                  style: _hasRepeatSettings
                      ? OutlinedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                  icon: Icon(
                    _isRepeatExpanded ? Icons.expand_less : Icons.repeat,
                    size: 18,
                  ),
                  label: const Text('繰り返し設定'),
                ),
              ],
            ),
            if (_isRepeatExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '繰り返し期間',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String?>(
                      value: _repeatInterval,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() => _repeatInterval = value);
                      },
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('なし'),
                        ),
                        ..._repeatIntervalOptions.map(
                          (v) => DropdownMenuItem<String?>(
                            value: v,
                            child: Text(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '繰り返し期限',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String?>(
                      value: _repeatEndType,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() => _repeatEndType = value);
                      },
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('なし'),
                        ),
                        ..._repeatEndTypeOptions.map(
                          (v) => DropdownMenuItem<String?>(
                            value: v,
                            child: Text(v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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

            // 非通知設定
            Row(
              children: [
                FilterChip(
                  label: const Text('通知しない'),
                  selected: _isMuted,
                  onSelected: (value) {
                    setState(() => _isMuted = value);
                  },
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
                                final isSelected = _selectedTags.contains(tag);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(tag),
                                    selected: isSelected,
                                    onSelected: (bool selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTags.add(tag);
                                        } else {
                                          _selectedTags.remove(tag);
                                        }
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
