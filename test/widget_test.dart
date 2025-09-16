// main.dart

import 'package:flutter/material.dart';

// Define MyApp class if missing
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Village Market')),
        body: const Center(
          child: CounterWidget(),
        ),
      ),
    );
  }
}

// Example CounterWidget for testing
class CounterWidget extends StatefulWidget {
  const CounterWidget({Key? key}) : super(key: key);

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$_counter'),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            setState(() {
              _counter++;
            });
          },
        ),
      ],
    );
  }
}

// Your main function and other code
void main() {
  runApp(const MyApp());
}