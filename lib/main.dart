import 'package:flutter/material.dart';
import 'package:steps_tracker/features/home/dashboard.dart';
// import 'dart:js_interop';

void main() {
  runApp(TravelTrackerApp());
}

class TravelTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TravelTrackerScreen(),
    );
  }
}
