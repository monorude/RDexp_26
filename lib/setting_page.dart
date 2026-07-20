import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'period_time_store.dart';
import 'NormalTask.dart';

const String _kAutoDeleteEnabled = 'auto_delete_enabled';
const String _kAutoDeleteDuration = 'auto_delete_duration';
const String _kThemeColor = 'theme_color'; // ✨ テーマカラーのキーを追加

// バグ報告フォームのURL
const String _bugReportUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSfubyfu5estIsiRhbL5yZUKtsndyTm-9JCHi0daQPYd_tZqFA/viewform?usp=header';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  static const int _periodCount = PeriodTimeStore.periodCount;

  late List<TimeOfDay> _periodStartTimes;

  bool _autoDeleteEnabled = false;
  String _autoDeleteDuration = '1ヶ月';
  String _themeColor = 'purple'; // ✨ テーマカラーの状態変数を追加

  static const List<String> _durationOptions = [
    '1ヶ月',
    '3ヶ月',
    '6ヶ月',
    '1年',
    '2年',
  ];

  // ✨ テーマカラーの選択肢マッピング（内部値 : 表示名）
  static const Map<String, String> _themeOptions = {
    'purple': 'パープル（デフォルト）',
    'blue': 'ブルー',
    'red': 'レッド',
    'green': 'グリーン',
    'orange': 'オレンジ',
  };

  @override
  void initState() {
    super.initState();
    _periodStartTimes = List.generate(
      _periodCount,
      (i) => PeriodTimeStore.getTime(i + 1),
    );
    final box = Hive.box('tasks');
    _autoDeleteEnabled =
        box.get(_kAutoDeleteEnabled, defaultValue: false) as bool;
    _autoDeleteDuration =
        box.get(_kAutoDeleteDuration, defaultValue: '1ヶ月') as String;

    // ✨ 保存されているテーマカラーを取得
    _themeColor = box.get(_kThemeColor, defaultValue: 'purple') as String;
  }

  Future<void> _pickTime(int periodIndex) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _periodStartTimes[periodIndex],
    );
    if (picked != null) {
      await PeriodTimeStore.setTime(periodIndex + 1, picked);
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
      final box = Hive.box('tasks');
      // 日付キー（タスク・マーカー）のみ削除し、時間割・設定キーは残す
      final taskKeys = box.keys.where((k) {
        if (k is! String) return false;
        final dateStr = k.replaceAll(RegExp(r'_(plain|period)$'), '');
        return DateTime.tryParse(dateStr) != null;
      }).toList();
      await box.deleteAll(taskKeys);
      final normalBox = Hive.box<NormalTask>('normalTasks');
      await normalBox.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('すべてのタスクを削除しました')));
      }
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
          // 授業開始時間の設定（折りたたみ、初期状態は閉じた状態）
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            initiallyExpanded: false,
            title: Text(
              '授業開始時間の設定',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: List.generate(
              _periodCount,
              (i) => _PeriodTimeTile(
                period: i + 1,
                time: _periodStartTimes[i],
                onTap: () => _pickTime(i),
              ),
            ),
          ),

          // ✨ 新設：デザイン設定セクション
          const Divider(height: 32),
          _SectionHeader(title: 'デザイン設定'),
          ListTile(
            title: const Text('テーマカラー'),
            trailing: DropdownButton<String>(
              value: _themeColor,
              items: _themeOptions.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _themeColor = value);
                  Hive.box('tasks').put(_kThemeColor, value); // Hiveに即時保存
                }
              },
            ),
          ),

          const Divider(height: 32),
          _SectionHeader(title: '完了済みタスクの自動削除'),
          SwitchListTile(
            title: const Text('一定期間後に自動で削除する'),
            value: _autoDeleteEnabled,
            onChanged: (value) {
              setState(() => _autoDeleteEnabled = value);
              Hive.box('tasks').put(_kAutoDeleteEnabled, value);
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
                    setState(() => _autoDeleteDuration = value);
                    Hive.box('tasks').put(_kAutoDeleteDuration, value);
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
          const Divider(height: 32),
          _SectionHeader(title: 'サポート'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('バグを報告する'),
              onPressed: () async {
                final uri = Uri.parse(_bugReportUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(title: 'バージョン情報'),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('バージョン'),
            trailing: Text('v0.13.0'),
          ),
          const ListTile(leading: Text('RDExp_13_2@2026')),
          const SizedBox(height: 16),
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
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('$period 時限'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time.format(context),
            style: Theme.of(context).textTheme.bodyMedium,
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
