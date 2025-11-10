import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_dev_project/utils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:file_picker/file_picker.dart'; //File Picker
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); //load api keys

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp(
      name: 'llmtest-ec773',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const ProviderScope(child: Calendar()));
}

class Calendar extends StatelessWidget {
  const Calendar({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFB8C4FF)),
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

void pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles();

  if (result != null) {
    File file = File(result.files.single.path!);
  }
}

List<Event> _getEventsForDay(DateTime day) => kEvents[day] ?? [];

class _MyHomePageState extends State<MyHomePage> {
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late final ValueNotifier<List<Event>> _selectedEvents;

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  static const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'your_channel_id',
    'your_channel_name',
    channelDescription: 'your channel description',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) async {
        debugPrint('Tapped payload: ${r.payload}');
      },
    );
  }

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initNotifications();
    _requestNotificationPermission();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier<List<Event>>(
      _getEventsForDay(_selectedDay!),
    );
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Builder(
            builder: (drawerContext) => NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
                Navigator.pop(drawerContext);

                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatApp()),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatApp()),
                  );
                }
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat),
                  label: Text('Add/Remove events'),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            children: <Widget>[
              TableCalendar<Event>(
                firstDay: kFirstDay,
                lastDay: kLastDay,
                focusedDay: _focusedDay,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _selectedEvents.value = _getEventsForDay(selectedDay);
                  }
                },
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ValueListenableBuilder<List<Event>>(
                  valueListenable: _selectedEvents,
                  builder: (context, value, _) {
                    if (value.isEmpty) return const Center(child: Text('No events'));
                    return ListView.builder(
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        final e = value[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(12.0)),
                          child: ListTile(
                            onTap: () async => await flutterLocalNotificationsPlugin.show(
                              0,
                              'These are your event details!',
                              '$e' + ' starting at ${e.start.hour.toString()}',
                              platformChannelSpecifics,
                              payload: 'Notification Payload',
                            ),
                            title: Text(e.title),
                            subtitle: Text(
                              '${e.start.hour.toString().padLeft(2, '0')}:${e.start.minute.toString().padLeft(2, '0')}'
                                  ' - '
                                  '${e.end.hour.toString().padLeft(2, '0')}:${e.end.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              FilledButton(onPressed: pickFile, child: const Text('Upload')),
            ],
          ),
        ),
      ),
    );
  }
}

