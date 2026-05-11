import 'package:flutter/material.dart';

class SettingPage extends StatelessWidget {
  const SettingPage ({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("hoge"),
      ),
      body: Center(
        child: Text(
          "setting page place holeder",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
