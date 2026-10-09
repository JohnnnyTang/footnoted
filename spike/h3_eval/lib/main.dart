import 'package:flutter/material.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'h3_eval',
      home: Scaffold(body: Center(child: Text('h3_eval (S01-13 placeholder)'))),
    );
  }
}
