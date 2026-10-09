import 'package:flutter/material.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'render_bench',
      home: Scaffold(
        body: Center(child: Text('render_bench (S01-12 placeholder)')),
      ),
    );
  }
}
