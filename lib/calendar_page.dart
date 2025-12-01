import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/picker.dart';
import 'databaseUtils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'chat_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'event.dart';
import 'package:intl/intl.dart';
import 'ics_import.dart';
import 'rrule_generator_helper.dart';
import './services/notification_service.dart';

final notifTimeFormatter = DateFormat('h:mm a');
final pickerDateTimeFormatter = DateFormat('dd MMM yyyy h:mm a');
final pickerDateFormatter = DateFormat('dd MMM yyyy');

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  State<Calendar> createState() => _CalendarState();
// Widget build(BuildContext context) {
//   return MaterialApp(
//     title: 'Calendar App',
//     theme: theme,
//     // MyHomePage is wrapped in a FutureBuilder internally now.
//     home: const CalendarHomePage(title: ''),
//   );
// }
}

class _CalendarState extends State<Calendar> {
  bool darkMode = false;

  ThemeData theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFB8C4FF),
    ),
  );

  void toggleTheme() {
    setState(() {
      darkMode = !darkMode;
      theme = darkMode ? ThemeData.dark() : ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8C4FF),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: CalendarHomePage(
        title: '',
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key, required this.title, required this.toggleTheme});
  final String title;
  final VoidCallback toggleTheme;

  @override
  State<CalendarHomePage> createState() => _CalendarHomePage();
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
  int id;

  final db_helper = DatabaseHelper();
  if (result != null) {
    Event? newEvent = result.event;
    if (specifier == 1) {
      //int id = db_helper.editEvent(evTitle, start, end, newEvent);
      print("Editing");

      onUpdate();
    } else if (newEvent != null) {
      id = await db_helper.insertEvent(newEvent);
      print("adding");
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

  // --- CHANGE 1: Set Default "Never" for new events ---
  String? repeatRule = "Never";
  String repeatTitle = "Event Repetition";
  String repeatDisplay = "Repeat";
  DateTime repeatEndDate = DateTime(
    2050,
    event.startTime.month,
    event.startTime.day,
    0,
    0,
    0,
  );

  List<String> repeatOptions = [
    "Never",
    "Daily",
    "Weekly",
    "Bi-Weekly",
    "Monthly",
    "Yearly",
  ];

  if (specifier == 1) {
    // Delete/Edit Mode
    repeatOptions = ["This Event", "All Events"];
    repeatTitle = "Delete Amount";
    repeatDisplay = "Delete Option";
    // --- CHANGE 2: Set Default "This Event" for delete mode ---
    repeatRule = "This Event";
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
                    decoration: InputDecoration(labelText: "Title", labelStyle: TextStyle(fontSize: 21)),
                  ),

                  const SizedBox(height: 15),

                  Text("Start:", style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(90), // optional
                        ),
                        child: SizedBox(
                          height: 35,
                          child: TextButton(
                            onPressed: () async {
                              final picked = await _showDatePicker(context, start);
                              if (picked != null) {
                                setState(() {
                                  start = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    start.hour,
                                    start.minute,
                                  );
                                });
                              }
                            },
                            child: Text(pickerDateFormatter.format(start)),
                          ),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(90), // optional
                        ),
                        child: SizedBox(
                          height: 35,
                          child: TextButton(
                            onPressed: () async {
                              final picked = await _showTimePicker(context, start);
                              if (picked != null) {
                                setState(() {
                                  start = DateTime(
                                    start.year,
                                    start.month,
                                    start.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            child: Text(notifTimeFormatter.format(start)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text("End:", style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(90), // optional
                        ),
                        child: SizedBox(
                          height: 35,
                          child: TextButton(
                            onPressed: () async {
                              final picked = await _showDatePicker(context, end);
                              if (picked != null) {
                                setState(() {
                                  end = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    end.hour,
                                    end.minute,
                                  );
                                });
                              }
                            },
                            child: Text(pickerDateFormatter.format(end)),
                          ),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(90), // optional
                        ),
                        child: SizedBox(
                          height: 35.0,
                          child: TextButton(
                            onPressed: () async {
                              final picked = await _showTimePicker(context, end);
                              if (picked != null) {
                                setState(() {
                                  end = DateTime(
                                    end.year,
                                    end.month,
                                    end.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            child: Text(notifTimeFormatter.format(end)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  // REPEAT RULE BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(elevation: 5),
                    onPressed: () async {
                      // --- CHANGE 3: Calculate index so the wheel opens on the selected item ---
                      int selectedIndex = repeatOptions.indexOf(
                        currentRepeatDisplay,
                      );
                      if (selectedIndex == -1) selectedIndex = 0;

                      await Picker(
                        adapter: PickerDataAdapter<String>(
                          pickerData: repeatOptions,
                        ),
                        // Pass the calculated index here
                        selecteds: [selectedIndex],
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
                    child: Text(currentRepeatDisplay),
                  ),

                  const SizedBox(height: 5),
                  const Text(
                    "Repeat Options",
                    style: TextStyle(fontSize: 12),
                  ),

                  if (repeatRule != "Never" && specifier == 0) ...[
                    const SizedBox(height: 20),
                    const Text("Repeat End Date", style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 7),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(90), // optional
                      ),
                      child: SizedBox(
                        height: 35.0,
                        child: TextButton(
                          onPressed: () async {
                            final picked = await _showDatePicker(context, repeatEndDate);
                            if (picked != null) {
                              setState(() {
                                repeatEndDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  23,
                                  59,
                                  59,
                                );
                              });
                            }
                          },
                          child: Text(pickerDateFormatter.format(repeatEndDate)),
                        ),
                      ),
                    ),
                  ],
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
                  // DELETE BUTTON
                  onPressed: repeatRule == null
                      ? null
                      : () {
                          deleteEvent(event, repeatRule!, onUpdate);
                          Navigator.pop(context, null);
                        },
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color: repeatRule == null ? Colors.grey : Colors.red,
                    ),
                  ),
                ),

              TextButton(
                // SAVE BUTTON
                // Since we set a default repeatRule, this button will now be active immediately
                onPressed: (specifier == 0 && repeatRule == null)
                    ? null
                    : () {
                        if (specifier == 1) {
                          // Logic for Editing an existing event
                          // (Note: Your original logic here seemed to delete and re-insert)
                          repeatRule = "This Event";
                          deleteEvent(event, repeatRule!, onUpdate);
                          final db_helper = DatabaseHelper();
                          db_helper.insertEvent(
                            Event(
                              title: titleController.text,
                              description: event.description,
                              startTime: start,
                              endTime: end,
                              rrule: "",
                              parentId: event.id!,
                              exdate: "",
                            ),
                          );
                        } else {
                          // Logic for New Event
                          repeatRule = generateIcsRrule(
                            option: repeatRule!,
                            endDate: repeatEndDate,
                          );
                        }

                        Navigator.pop(context, (
                          event: Event(
                            title: titleController.text,
                            description: "",
                            startTime: start,
                            endTime: end,
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

Future<DateTime?> _showDatePicker(
    BuildContext context,
    DateTime? date,
    ) async {
  DateTime? day;

  await Picker(
    adapter: DateTimePickerAdapter(
      type: PickerDateTimeType.kYMD,
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

Future<DateTime?> _showTimePicker(
    BuildContext context,
    DateTime? date,
    ) async {
  DateTime? day;

  await Picker(
    adapter: DateTimePickerAdapter(
      type: PickerDateTimeType.kHM,
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
  Color dailyEventBorderColour = Colors.black;
  Color calendarDots = Colors.deepOrangeAccent;
  Color sideBarTextColour = Colors.black;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  // Initialize with an empty value listener until events are loaded
  late ValueNotifier<List<DisplayEvent>> _selectedEvents = ValueNotifier([]);

  /// Schedules a notification for each event one hour before it starts.
  Future<void> _scheduleAllEventNotifications(
    LinkedHashMap<DateTime, List<DisplayEvent>> eventsMap,
  ) async {
    await NotificationService.cancelAllNotifications();

    //  Convert the map of lists into a single flat list
    final allEvents = eventsMap.values.expand((list) => list).toList();

    //  Define the current time and iterate through all events
    final now = DateTime.now();

    for (var event in allEvents) {
      // Calculate the time one hour before the event
      final notificationTime = event.startTime.subtract(
        const Duration(hours: 1),
      );

      // Ensure the notification is for a future time
      if (notificationTime.isAfter(now)) {
        // Use a unique integer ID for the notification.
        // Using the modulo operator to ensure the ID fits within a 32-bit signed integer.
        final int id = event.startTime.millisecondsSinceEpoch % 2147483647;

        final title = 'Event Reminder: ${event.title}';
        final body = 'Your event starts in one hour!';

        await NotificationService.scheduleNotification(
          id: id,
          title: title,
          body: body,
          scheduledTime: notificationTime,
        );
      }
    }
  }

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
      _eventsFuture.then((eventsMap) {
        _scheduleAllEventNotifications(eventsMap);
      });
      _selectedEvents.value = [];
    });
  }

  void changeEventBorderColour() {
    if (dailyEventBorderColour == Colors.black) {
      dailyEventBorderColour = Colors.white70;
    } else {
      dailyEventBorderColour = Colors.black;
    }

    if (calendarDots == Colors.deepOrangeAccent) {
      calendarDots = Colors.yellow;
    } else {
      calendarDots = Colors.deepOrangeAccent;
    }

    if (sideBarTextColour == Colors.black) {
      sideBarTextColour = Colors.white;
    } else {
      sideBarTextColour = Colors.black;
    }
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
    await saveIcsToDatabase(icsText);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar updated')),
    );

    _updateCalendar();
  }

  @override
  void initState() {
    super.initState();
    // Call the db to get events

    _eventsFuture = getEventsFromDatabase();
    _eventsFuture.then((eventsMap) {
      _scheduleAllEventNotifications(eventsMap);
    });

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
              selectedIndex: null,
              onDestinationSelected: (int index) async {
                //setState(() => _selectedIndex = index);
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
                } else if (index == 2) {
                  changeEventBorderColour();
                  widget.toggleTheme();
                }
              },
              labelType: NavigationRailLabelType.all,
              unselectedLabelTextStyle: TextStyle(fontSize: 18, color: sideBarTextColour),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined, size: 43),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_outlined, size: 35),
                  label: Text('AI chat'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.invert_colors, size: 40),
                  label: Text('Colour Theme'),
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
                  Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: Colors.grey,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TableCalendar<DisplayEvent>(
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
                        calendarStyle: CalendarStyle(
                          markerDecoration: BoxDecoration(
                            color: calendarDots,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  SizedBox(
                    width: 150.0,
                    height: 50.0,
                    child: FilledButton(
                      onPressed: () async {
                        String? events = await importIcsFile();
                        if (events != null) {
                          await _addEventFromIcs(events);
                        }
                      },
                      child: const Text('Upload'),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  SizedBox(
                    width: 150.0,
                    height: 50.0,
                    child: FilledButton(
                      onPressed: () => addEditEvent(
                        context,
                        0,
                        Event(
                          title: "",
                          description: "",
                          startTime: _focusedDay,
                          endTime: _focusedDay,
                          rrule: "",
                          parentId: 0,
                          exdate: "",
                        ),
                        _updateCalendar, // Passed callback
                      ),
                      child: const Text('Add Event'),
                    ),
                  ),
                  const SizedBox(height: 30.0),
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
                                border: Border.all(color: dailyEventBorderColour),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: ListTile(
                                onTap: () async =>
                                    await flutterLocalNotificationsPlugin.show(
                                      0,
                                      'These are your event details!',
                                      '${e.title}' + ' starting at ${e.startTime.hour.toString()} and ending at ${e.endTime.hour.toString()}',
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

List<Event> parseIcsToDisplayEvents(String icsText) {
  final events = <Event>[];
  final blocks = icsText.split('BEGIN:VEVENT');
  for (final block in blocks) {
    if (!block.contains('END:VEVENT')) continue;
    String? title;
    DateTime? start;
    DateTime? end;
    String rrule = "";
    List<String> exdates = [];
    String exDates = "";
    final lines = block.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    for (final line in lines) {
      if (line.startsWith('SUMMARY:')) {
        title = line.substring('SUMMARY:'.length).trim();
      } else if (line.startsWith('DTSTART')) {
        start = _parseIcsDate(line);
      } else if (line.startsWith('DTEND')) {
        end = _parseIcsDate(line);
      } else if (line.startsWith('RRULE')) {
        rrule = line.trim();
      } else if (line.startsWith("EXDATE")) {

        final raw = line.substring(line.indexOf(":") + 1).trim();
        final parts = raw.split(",");

        for (final p in parts) {
          final value = p.trim();
          if (value.isNotEmpty && !exdates.contains(value)) {
            exdates.add(value);
          }
        }
      }
    }

    if (exdates.isNotEmpty) {
      exDates = "EXDATE:${exdates.join(",")}";
    }

    if (title != null && start != null && end != null) {
      events.add(
        Event(
          id: null,
          title: title,
          description: '',
          startTime: start,
          endTime: end,
          rrule: rrule,
          parentId: -1, // -1 means new event in the DB
          exdate: exDates,
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
