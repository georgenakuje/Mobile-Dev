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
import 'rrule_generator_helper.dart';

final notifTimeFormatter = DateFormat('h:mm a');
final pickerTimeFormatter = DateFormat('dd MMM yyyy h:mm a');

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

void addEditEvent(
  BuildContext context,
  int specifier,
  Event event,
  VoidCallback onUpdate,
) async {
  String evTitle = "New Event";
  String addOrEdit = "New Event";
  if (specifier == 1) {
    evTitle = event.title;
    addOrEdit = "Edit Event";
  }

  final result = await addEditEventPopOut(
    addOrEdit,
    context,
    event,
    evTitle,
    specifier,
    onUpdate,
  );
  final db_helper = DatabaseHelper();
  int id;

  if (result != null) {
    Event? newEvent = result.event;
    if (specifier == 1) {
      //int id = db_helper.editEvent(evTitle, start, end, newEvent);
      print("Editing");
      onUpdate();
    } else if (newEvent != null) {
      id = await db_helper.insertEvent(newEvent);
      print("adding");
      print(id);
      print(newEvent.title);
      onUpdate();
    }
  }
}

Future<({Event? event, String freq})?> addEditEventPopOut(
  String addOrEdit,
  BuildContext context,
  Event event,
  String title,
  int specifier,
  VoidCallback onUpdate,
) async {
  final titleController = TextEditingController(text: title);
  DateTime start = event.startTime;
  DateTime end = event.endTime;

  String? repeatRule;
  String repeatTitle = "Event Repetition";
  String repeatDisplay = "Repeat";

  List<String> repeatOptions = [
    "Never",
    "Daily",
    "Weekly",
    "Bi-Weekly",
    "Monthly",
    "Yearly",
  ];

  if (specifier == 1) {
    repeatOptions = ["This Event", "All Events"];
    repeatTitle = "Delete Amount";
    repeatDisplay = "Delete Option";
  }

  return showDialog<({Event? event, String freq})>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          String currentRepeatDisplay = repeatRule ?? repeatDisplay;

          return AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
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
                        setState(() {
                          start = picked;
                        });
                      }
                    },
                    child: Text(pickerTimeFormatter.format(start)),
                  ),

                  Text("End:"),
                  TextButton(
                    onPressed: () async {
                      final picked = await _showDateTimePicker(context, end);
                      if (picked != null) {
                        setState(() {
                          end = picked;
                        });
                      }
                    },
                    child: Text(pickerTimeFormatter.format(end)),
                  ),

                  // REPEAT RULE BUTTON (for both Add/Edit and Delete)
                  TextButton(
                    onPressed: () async {
                      await Picker(
                        adapter: PickerDataAdapter<String>(
                          pickerData: repeatOptions,
                        ),
                        hideHeader: false,
                        title: Text(repeatTitle),
                        height: 250,
                        itemExtent: 40,
                        onConfirm: (Picker picker, List value) {
                          setState(() {
                            repeatRule = picker.getSelectedValues()[0];
                          });
                        },
                      ).showModal(context);
                    },
                    // ⭐️ Uses the dynamic display text
                    child: Text(currentRepeatDisplay),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text("Cancel"),
              ),

              if (specifier == 1)
                TextButton(
                  // DELETE BUTTON: Check if a delete option has been selected
                  onPressed: repeatRule == null
                      ? null
                      : () {
                          deleteEvent(event, repeatRule!, onUpdate);
                          Navigator.pop(context, null);
                        },
                  // Set the style based on whether an option is selected
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color: repeatRule == null ? Colors.grey : Colors.red,
                    ),
                  ),
                ),

              TextButton(
                // SAVE BUTTON: Check if a repeat option has been selected for a NEW event
                onPressed: (specifier == 0 && repeatRule == null)
                    ? null
                    : () {
                        repeatRule = generateIcsRrule(
                          option: repeatRule!,
                          endDate: end,
                        );

                        // If specifier == 1 (Edit), repeatRule is for delete, which is irrelevant for Save.
                        // If specifier == 0 (New), repeatRule must be set (or defaulted if necessary).
                        Navigator.pop(context, (
                          event: Event(
                            title: titleController.text,
                            description: "",
                            startTime: start,
                            endTime: end,
                            // Use a default value if creating a new event and repeatRule is still null
                            rrule: repeatRule ?? "",
                            parentId: 0,
                            exdate: "",
                          ),
                          freq: repeatRule ?? "",
                        ));
                      },
                child: Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<DateTime?> _showDateTimePicker(
  BuildContext context,
  DateTime? date,
) async {
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

void deleteEvent(Event event, String freq, VoidCallback onUpdate) async {
  final db_helper = DatabaseHelper();

  print("Deleting event: ${event.title}, Frequency: $freq");

  Event? fetchedEvent = await db_helper.fetchById(event.id);

  if (fetchedEvent == null) {
    return;
  }

  // Case 1: Delete all occurrences (or a non-recurring event)
  if (freq == "All Events" ||
      (freq == "This Event" &&
          (fetchedEvent.rrule == null || fetchedEvent.rrule == ""))) {
    // This covers non-recurring events, or when the user explicitly chose to delete all
    int result = await db_helper.deleteEvent(event.id!);
    print("Deleted event event with ID: ${event.id}, Result: $result");
  }
  // Case 2: Delete only the current occurrence (by adding an EXDATE)
  else if (freq == "This Event" &&
      fetchedEvent.rrule != null &&
      fetchedEvent.rrule != "") {
    int? id = event.id;
    DateTime dateToExclude =
        event.startTime; // Use the start time of the instance

    int result = await db_helper.addExdateToEvent(id!, dateToExclude);
    print(
      "Added EXDATE for instance ${event.startTime} to master event ID: $id, Result: $result",
    );
  }

  // After the database operation is complete, refresh the calendar.
  onUpdate();
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

  void _updateCalendar() {
    setState(() {
      _eventsFuture = getEventsFromDatabase();
      _selectedEvents.value = [];
    });
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

  Future<void> _addEventFromIcs(String icsText) async {
    final events = parseIcsToDisplayEvents(icsText);
    final dbHelper = DatabaseHelper();

    for (final d in events) {
      final event = Event(
        id: null,
        title: d.title,
        description: d.description,
        startTime: d.startTime,
        endTime: d.endTime,
        rrule: "",
        parentId: d.parentId,
        exdate: "",
      );
      await dbHelper.insertEvent(event);
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event Added!')));
      _updateCalendar();
    }
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
              onDestinationSelected: (int index) async {
                setState(() => _selectedIndex = index);
                Navigator.pop(drawerContext);

                if (index == 1) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen((icsText) async {
                        await _addEventFromIcs(icsText);
                        // The call to _updateCalendar is now inside _addEventFromIcs
                      }),
                    ),
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
                  const SizedBox(height: 8.0),
                  FilledButton(
                    onPressed: () => addEditEvent(
                      context,
                      0,
                      Event(
                        title: "",
                        description: "",
                        startTime: DateTime.now(),
                        endTime: DateTime.now(),
                        rrule: "",
                        parentId: 0,
                        exdate: "",
                      ),
                      _updateCalendar, // Passed callback
                    ),
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
                                trailing: IconButton(
                                  onPressed: () {
                                    addEditEvent(
                                      context,
                                      1,
                                      Event(
                                        id: e.id,
                                        title: e.title,
                                        description: e.description,
                                        startTime: e.startTime,
                                        endTime: e.endTime,
                                        rrule: "",
                                        parentId: 0,
                                        exdate: "",
                                      ),
                                      _updateCalendar, // Passed callback
                                    );
                                  },
                                  icon: Icon(Icons.edit),
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

List<DisplayEvent> parseIcsToDisplayEvents(String icsText) {
  final events = <DisplayEvent>[];
  final blocks = icsText.split('BEGIN:VEVENT');
  for (final block in blocks) {
    if (!block.contains('END:VEVENT')) continue;
    String? title;
    DateTime? start;
    DateTime? end;
    final lines = block.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    for (final line in lines) {
      if (line.startsWith('SUMMARY:')) {
        title = line.substring('SUMMARY:'.length).trim();
      } else if (line.startsWith('DTSTART')) {
        start = _parseIcsDate(line);
      } else if (line.startsWith('DTEND')) {
        end = _parseIcsDate(line);
      }
    }
    if (title != null && start != null && end != null) {
      events.add(
        DisplayEvent(
          id: null,
          title: title,
          description: '', // empty description is fine
          startTime: start,
          endTime: end,
          parentId: -1, // -1 is your “new event” sentinel in the DB
        ),
      );
    }
  }
  return events;
}

DateTime _parseIcsDate(String line) {
  final parts = line.split(':');
  final value = parts.last.trim();
  if (value.endsWith('Z')) {
    return DateTime.parse(value).toLocal();
  }
  if (value.length == 15) {
    return DateTime.parse(
      '${value.substring(0, 4)}-'
      '${value.substring(4, 6)}-'
      '${value.substring(6, 8)} '
      '${value.substring(9, 11)}:'
      '${value.substring(11, 13)}:'
      '${value.substring(13, 15)}',
    );
  } else if (value.length == 13) {
    return DateTime.parse(
      '${value.substring(0, 4)}-'
      '${value.substring(4, 6)}-'
      '${value.substring(6, 8)} '
      '${value.substring(9, 11)}:'
      '${value.substring(11, 13)}:00',
    );
  } else {
    return DateTime.parse(value);
  }
}
