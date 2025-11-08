import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart'; //Calendar
import 'package:file_picker/file_picker.dart'; //File Picker

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF5D5F6E)),
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

void pickFile() async{
  FilePickerResult? result = await FilePicker.platform.pickFiles();

  if (result != null) {
    File file = File(result.files.single.path!);
  }
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(onPressed: () {}, child: Icon(Icons.menu)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: SfCalendar(
                view: CalendarView.schedule,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: FilledButton(
                onPressed: pickFile,
                child: const Text('Upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


