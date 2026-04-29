import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/table_calender_sample.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  initializeDateFormatting('ja');
  runApp(const MyApp());
}//メイン関数。起動要求がくるとこれが動く。
 //やっていることは、init~で日付のフォーマットを日本語にし、runAppでMyAppクラスを動かしている。

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'hoge'),
    );
  }
}//Myappクラス。多分アプリ全体のテーマとかを決めるクラス。MyHomepageにタイトルを渡して起動？

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}//MyHomePageクラス。MyAppから受け取ったtitleを……どうしてるんですかね。これは。

class ClockTimer extends StatefulWidget{
  @override
  State<ClockTimer> createState() {
    return _ClockTimerState();
  }
}//毎秒更新用タイマーの起動用クラス State<ClockTimer>の抽象クラス？

class _ClockTimerState extends State<ClockTimer> {
  String _time = '';

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), _onTimer);
  }
  void _onTimer(Timer timer) {
    var now = DateTime.now();
    var date = DateFormat.Hms('ja').format(now).toString();
    var timeString = DateFormat.yMMMMEEEEd('ja').format(now).toString();
    setState(() => 
      _time = '$timeString $date ',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _time,
    );
  }
}//毎秒更新用タイマーの本体。
 //https://zenn.dev/lisras/articles/d5b21d89ab4fa2 を参照。



class _MyHomePageState extends State<MyHomePage> {

  void _incrementCounter() {
    setState(() {
    });
  }

  String getTodayDate() {
    initializeDateFormatting('ja');

    return DateFormat.yMMMMEEEEd('ja').format(DateTime.now()).toString();
  }


//以下のwidget関数が、アプリの表示などを司っている。
//Scaffold()はそれを記述する箱のようなもの？
//要素の追加は、body:内にchild:として記述していくこととなる。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(children: [
        Center(
          child: Container(
            width: 288,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.blue),
            child: ClockTimer(),
          ),
        ),

      
        Expanded(
          child:TableCalendarSample(),
        ),
      ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
