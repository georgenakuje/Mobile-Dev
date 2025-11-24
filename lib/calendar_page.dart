import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/picker.dart';
import 'databaseUtils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:file_picker/file_picker.dart';
import 'chat_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'event.dart';
import 'package:intl/intl.dart';

final notifTimeFormatter = DateFormat('h:mm a');
final pickerTimeFormatter = DateFormat('yyyy:MM:dd h:mm a');

class Calendar extends StatelessWidget {
  const Calendar({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB8C4FF)),
      ),
      // MyHomePage is wrapped in a FutureBuilder internally now.
      home: const CalendarHomePage(title: ''),
    );
  }
}

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key, required this.title});
  final String title;

  @override
  State<CalendarHomePage> createState() => _CalendarHomePage();
}

void pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles();

  if (result != null) {
    File file = File(result.files.single.path!);
  }
}




void addEditEvent(BuildContext context, int specifier, Event event) async {
  DateTime start = DateTime.now();
  DateTime end = DateTime.now();
  String evTitle = "New Event";
  String addOrEdit = "New Event";
  if (specifier == 1) {
    start = event.startTime;
    end = event.endTime;
    evTitle = event.title;
    addOrEdit = "Edit Event";
  }

  Event? newEvent = await addEditEventPopOut(addOrEdit, context, event, evTitle, specifier);
  final db_helper = DatabaseHelper();
  int id;

  if (newEvent != null) {
    if (specifier == 1) {
      print("Editing");//int id = db_helper.editEvent(evTitle, start, end, newEvent);
    }
    else {
      id = await db_helper.insertEvent(newEvent);
    }
  }


  // create popup box that has text box for title and 2 text sections
  // that format a DateTime into readable value
  // text box onPressed() should allow edit
  // both time boxes should call _ShowDateTimePicker(context, start/end) respectively
  // at end of functions should call insertEvent(event) for adding
  // and function may need to be created for editing existing event
  // that will take new values and old values so it knows what to replace
  // also include a delete button if the edit button is pressed (specifier = 1)


}

Future<Event?> addEditEventPopOut(String addOrEdit, BuildContext context, Event event, String title, int specifier) async {
  final titleController = TextEditingController(text: title);
  String? oldTitle = title;
  DateTime start = event.startTime;
  DateTime end = event.endTime;
  DateTime oldStart = start;

  return showDialog<Event> (
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(addOrEdit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: "Title"),
                ),

                const SizedBox(height: 12),

                Text("Start:"),
                TextButton(
                    onPressed: () async {
                      final picked = await _showDateTimePicker(context, start);
                      if (picked != null) {
                        start = picked;
                      }
                    },
                    child: Text(pickerTimeFormatter.format(start))
                ),

                Text("End:"),
                TextButton(
                    onPressed: () async {
                      final picked = await _showDateTimePicker(context, start);
                      if (picked != null) {
                        end = picked;
                      }
                    },
                    child: Text(pickerTimeFormatter.format(end))
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text("Cancel")
            ),

            if (specifier == 1)
              TextButton(
                onPressed: () {
                  deleteEvent(event);
                  Navigator.pop(context, null);
                },
                child: Text("Delete"),
              ),

            TextButton(
                onPressed: () {
                  Navigator.pop(
                      context,
                      Event(
                        title: titleController.text,
                        description: "",
                        startTime: start,
                        endTime: end,
                        rrule: "",
                        parentId: 0,
                        exdate: null,
                      )
                  );
                },
                child: Text("Save"),
            ),
          ],
        );
      },
  );
}




Future<DateTime?> _showDateTimePicker(BuildContext context, DateTime? date) async {
  DateTime? day;

  await Picker(
    adapter: DateTimePickerAdapter(
      type: PickerDateTimeType.kYMDHM,
      value: date ?? DateTime.now(),
      minValue: DateTime(1950),
      maxValue: DateTime(2050),
    ),
    title: const Text('Select Date & Time'),
    onConfirm: (Picker picker, List<int> value) async {
      day = (picker.adapter as DateTimePickerAdapter).value;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected: $day')));
    },
  ).showModal(context);
  return day;
}

void deleteEvent(Event event) {
  final db_helper = DatabaseHelper();

  print("Deleting");//int id = db_helper.deleteEvent(event);
}

class _CalendarHomePage extends State<CalendarHomePage> {
  // Use a Future to hold the result of the async database call
  late Future<LinkedHashMap<DateTime, List<DisplayEvent>>> _eventsFuture;

  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  // Initialize with an empty value listener until events are loaded
  late ValueNotifier<List<DisplayEvent>> _selectedEvents = ValueNotifier([]);

  // Helper function to get events for a day from the map
  List<DisplayEvent> _getEventsForDay(
    DateTime day,
    LinkedHashMap<DateTime, List<DisplayEvent>> eventsMap,
  ) {
    return eventsMap[day] ?? [];
  }

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
    // Call the db to get events
    _eventsFuture = getEventsFromDatabase();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initNotifications();
    _requestNotificationPermission();

    _selectedDay = _focusedDay;
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
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat),
                  label: Text('AI chat'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<LinkedHashMap<DateTime, List<DisplayEvent>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while fetching data
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Show an error message if the future fails
            return Center(
              child: Text('Error loading events: ${snapshot.error}'),
            );
          } else if (snapshot.hasData) {
            // Data successfully loaded, proceed with the calendar view
            final kEvents = snapshot.data!;

            // Initialize/Update _selectedEvents with the first day's events
            if (_selectedEvents.value.isEmpty && _selectedDay != null) {
              _selectedEvents = ValueNotifier<List<DisplayEvent>>(
                _getEventsForDay(_selectedDay!, kEvents),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                children: <Widget>[
                  TableCalendar<DisplayEvent>(
                    firstDay: kFirstDay,
                    lastDay: kLastDay,
                    focusedDay: _focusedDay,
                    // Pass a function that uses the loaded kEvents map
                    eventLoader: (day) => _getEventsForDay(day, kEvents),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        // Update the ValueNotifier with events from the loaded map
                        _selectedEvents.value = _getEventsForDay(
                          selectedDay,
                          kEvents,
                        );
                      }
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) =>
                        setState(() => _calendarFormat = format),
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                  ),
                  const SizedBox(height: 8.0),
                  FilledButton(
                    onPressed: pickFile,
                    child: const Text('Upload'),
                  ),
                  ElevatedButton(
                    onPressed: () => addEditEvent(context, 0, Event(title: "", description: "", startTime: DateTime.now(), endTime: DateTime.now(), rrule: "", parentId: 0, exdate: null)),
                    child: const Text('Add Event'),
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: ValueListenableBuilder<List<DisplayEvent>>(
                      valueListenable: _selectedEvents,
                      builder: (context, value, _) {
                        if (value.isEmpty) {
                          return const Center(child: Text('No events'));
                        }
                        return ListView.builder(
                          itemCount: value.length,
                          itemBuilder: (context, index) {
                            final e = value[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: ListTile(
                                onTap: () async =>
                                    await flutterLocalNotificationsPlugin.show(
                                      0,
                                      'These are your event details!',
                                      '$e' +
                                          ' starting at ${e.startTime.hour.toString()}',
                                      platformChannelSpecifics,
                                      payload: 'Notification Payload',
                                    ),
                                title: Text(e.title),
                                subtitle: Text(
                                  '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}'
                                  ' - '
                                  '${e.endTime.hour.toString().padLeft(2, '0')}:${e.endTime.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          // Default fallback
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
