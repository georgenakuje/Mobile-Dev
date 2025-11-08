import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
            onPressed: () {},
            child: Icon(Icons.menu)
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Column(
            children: <Widget>[
              TableCalendar(  firstDay: DateTime.now(),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: DateTime.now(),),
              FilledButton(
                onPressed: () {},
                child: const Text('Upload'),
              )
            ],
          ),
        )
      ),
    );
  }
}
