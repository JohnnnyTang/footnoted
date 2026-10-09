import 'package:flutter/material.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'storage_bench',
      home: Scaffold(
        body: Center(child: Text('storage_bench (S01-11 placeholder)')),
      ),
    );
  }
}
