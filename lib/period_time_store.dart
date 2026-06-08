import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 時限ごとの授業開始時刻を Hive に永続化する共有ストア。
/// setting_page.dart と add_event_screen.dart の両方から参照する。
class PeriodTimeStore {
  PeriodTimeStore._();

  /// アプリ全体で扱う時限数（setting_page に合わせて 6）
  static const int periodCount = 6;

  static const String _boxName = 'tasks';
  static const String _keyPrefix = 'period_time_';

  /// 初期値（未設定時のフォールバック）
  static const Map<int, TimeOfDay> defaults = {
    1: TimeOfDay(hour: 9, minute: 0),
    2: TimeOfDay(hour: 11, minute: 5),
    3: TimeOfDay(hour: 13, minute: 45),
    4: TimeOfDay(hour: 15, minute: 30),
    5: TimeOfDay(hour: 17, minute: 15),
    6: TimeOfDay(hour: 19, minute: 0),
  };

  static Box get _box => Hive.box(_boxName);

  /// 指定時限の開始時刻を取得する（未保存なら defaults を返す）
  static TimeOfDay getTime(int period) {
    final val = _box.get('$_keyPrefix$period') as String?;
    if (val == null) return defaults[period] ?? const TimeOfDay(hour: 9, minute: 0);
    final parts = val.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// 指定時限の開始時刻を保存する
  static Future<void> setTime(int period, TimeOfDay time) async {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    await _box.put('$_keyPrefix$period', '$h:$m');
  }
}
