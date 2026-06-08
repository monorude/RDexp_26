import 'package:flutter/material.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  static const int _periodCount = 6;

  final List<TimeOfDay?> _periodStartTimes = List.filled(_periodCount, null);

  bool _autoDeleteEnabled = false;
  String _autoDeleteDuration = '1ヶ月';

  static const List<String> _durationOptions = [
    '1ヶ月',
    '3ヶ月',
    '6ヶ月',
    '1年',
    '2年',
  ];

  Future<void> _pickTime(int periodIndex) async {
    final initial = _periodStartTimes[periodIndex] ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _periodStartTimes[periodIndex] = picked;
      });
    }
  }

  Future<void> _showClearAllConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクの全消去'),
        content: const Text('すべてのタスクを削除します。\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: 全タスク削除処理
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader(title: '授業開始時間の設定'),
          ...List.generate(_periodCount, (i) => _PeriodTimeTile(
            period: i + 1,
            time: _periodStartTimes[i],
            onTap: () => _pickTime(i),
          )),
          const Divider(height: 32),
          _SectionHeader(title: '完了済みタスクの自動削除'),
          SwitchListTile(
            title: const Text('自動で削除する'),
            value: _autoDeleteEnabled,
            onChanged: (value) {
              setState(() {
                _autoDeleteEnabled = value;
              });
            },
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _autoDeleteEnabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: ListTile(
              title: const Text('削除までの期間'),
              trailing: DropdownButton<String>(
                value: _autoDeleteDuration,
                items: _durationOptions
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _autoDeleteDuration = value;
                    });
                  }
                },
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
          const Divider(height: 32),
          _SectionHeader(title: 'タスク管理'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('すべてのタスクを削除'),
              onPressed: _showClearAllConfirmDialog,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _PeriodTimeTile extends StatelessWidget {
  const _PeriodTimeTile({
    required this.period,
    required this.time,
    required this.onTap,
  });

  final int period;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = time != null ? time!.format(context) : '未設定';
    return ListTile(
      title: Text('$period 時限'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: time != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.access_time),
            tooltip: '時刻を設定',
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
