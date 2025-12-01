import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'calendar_page.dart';
import 'databaseUtils.dart';
import 'event.dart';
import 'services/notification_service.dart'; // <-- correct import

Future<String?> importIcsFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['ics'],
  );

  if (result == null || result.files.single.path == null) {
    return null;
  }

  final file = File(result.files.single.path!);
  final content = await file.readAsString();

  // final calendar = ICalendar.fromString(content);
  // final events = <Event>[];
  //
  // final now = DateTime.now(); // current time for scheduling notifications
  //
  // for (final e in calendar.data) {
  //   try {
  //     DateTime? start;
  //     DateTime? end;
  //
  //     final rawStart = e['dtstart'];
  //     final rawEnd = e['dtend'];
  //
  //     if (rawStart is IcsDateTime) {
  //       start = rawStart.toDateTime();
  //     } else if (rawStart is String) {
  //       start = DateTime.tryParse(rawStart);
  //     }
  //
  //     if (rawEnd is IcsDateTime) {
  //       end = rawEnd.toDateTime();
  //     } else if (rawEnd is String) {
  //       end = DateTime.tryParse(rawEnd);
  //     }
  //
  //     final event = Event(
  //       title: e['summary'] ?? 'Untitled Event',
  //       description: e['description'] ?? '',
  //       startTime: start ?? DateTime.now(),
  //       endTime: end ?? (start?.add(const Duration(hours: 1)) ?? DateTime.now()),
  //       rrule: "",
  //       parentId: -1,
  //       exdate: "",
  //     );
  //
  //     events.add(event);
  //
  //     // --- Schedule a notification 1 hour before the event ---
  //     final notificationTime = event.startTime.subtract(const Duration(hours: 1));
  //     if (notificationTime.isAfter(now)) {
  //       NotificationService.scheduleNotification(
  //         id: event.startTime.hashCode,
  //         title: event.title,
  //         body: 'Event starting at ${event.startTime.hour}:${event.startTime.minute}',
  //         scheduledTime: notificationTime,
  //       );
  //     }
  //
  //   } catch (err, st) {
  //     print('⚠️ Error parsing event: $err');
  //     print(st);
  //   }
  // }

  return content;
}

Future<void> saveIcsToDatabase(String icsText) async {
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
}
