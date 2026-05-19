import 'dart:async';
import 'timetable_screen.dart'; // ← これを一番上に書き足す！
import 'package:flutter/material.dart';
import 'package:flutter_application_1/table_calender_sample.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'setting_page.dart';

void main() {
  initializeDateFormatting('ja');
  runApp(const MyApp());
} //メイン関数。起動要求がくるとこれが動く。
//やっていることは、init~で日付のフォーマットを日本語にし、runAppでMyAppクラスを動かしている。

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'hoge'),
    );
  }
} //Myappクラス。多分アプリ全体のテーマとかを決めるクラス。MyHomepageにタイトルを渡して起動？

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
} //MyHomePageクラス。MyAppから受け取ったtitleを……どうしてるんですかね。これは。

class ClockTimer extends StatefulWidget {
  @override
  State<ClockTimer> createState() {
    return _ClockTimerState();
  }
} //毎秒更新用タイマーの起動用クラス State<ClockTimer>の抽象クラス？

class _ClockTimerState extends State<ClockTimer> {
  String _time = '';
  // ★【追加】タイマーをキャンセルできるように、変数として保持する
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ★【修正】変数 _timer に代入する
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimer);
  }

  void _onTimer(Timer timer) {
    // ★【重要】画面がまだ存在している（mounted）ときだけ setState を呼ぶ
    if (!mounted) return;

    var now = DateTime.now();
    var date = DateFormat.Hms('ja').format(now).toString();
    var timeString = DateFormat.yMMMMEEEEd('ja').format(now).toString();
    setState(() => _time = '$timeString $date ');
  }

  // ★【追加】このウィジェットが消えるときに呼ばれる関数
  @override
  void dispose() {
    _timer?.cancel(); // タイマーを安全に停止する（メモリリーク防止）
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_time);
  }
} //毎秒更新用タイマーの本体。
//https://zenn.dev/lisras/articles/d5b21d89ab4fa2 を参照。

class _MyHomePageState extends State<MyHomePage> {
  // ★【書き足し①】今何番目のタブが選ばれているかを覚えておく変数
  int _currentIndex = 0;

  void _incrementCounter() {
    setState(() {});
  }

  String getTodayDate() {
    initializeDateFormatting('ja');
    return DateFormat.yMMMMEEEEd('ja').format(DateTime.now()).toString();
  }

  // 以下のwidget関数が、アプリの表示などを司っている。
  // Scaffold()はそれを記述する箱のようなもの？
  // 要素の追加は、body:内にchild:として記述していくこととなる。
  @override
  Widget build(BuildContext context) {
    // ★【書き足し②】切り替える2つの画面を配列（リスト）として定義します
    final List<Widget> _tabs = [
      // [0番目のタブ]: 元々 body にあった「時計 + カレンダー」の Column
      Column(
        children: [
          Center(
            child: Container(
              width: 288,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: ClockTimer(),
            ),
          ),
          Expanded(child: TableCalendarSample()),
        ],
      ),
      // [1番目のタブ]: 新しく作った時間割設定画面
      const TimetableScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // ★【書き換え】選ばれているタブに応じてタイトルを自動で切り替える
        title: Text(_currentIndex == 0 ? widget.title : '時間割設定'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'aaa',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.message),
              title: Text('Messages'),
            ),
            const ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Profile'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('hoges'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingPage()),
                );
              },
            ),
          ],
        ),
      ),

      // ★【書き換え】固定だった Column から、タブで選択された画面（_tabs の中身）を表示するように変更
      body: _tabs[_currentIndex],

      // ★【書き換え】右下のプラスボタンは、カレンダー（0番目）の時だけ表示し、時間割の時は非表示（null）にする
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _incrementCounter,
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            )
          : null,

      // ★【書き足し③】Scaffold の箱に、下部タブバー（BottomNavigationBar）を追加！
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // 今どっちが選ばれているか
        onTap: (index) {
          // タップされたら、選ばれた番号（0か1）を _currentIndex に保存して画面を再描画する
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: '時間割'),
        ],
      ),
    );
  }
}
