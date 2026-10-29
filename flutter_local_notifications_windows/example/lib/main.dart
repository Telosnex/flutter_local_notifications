import 'package:flutter/material.dart';

// The integration tests drive the plugin without UI. This app only gives the
// test a window to run in.
void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Example'))),
    ),
  );
}
