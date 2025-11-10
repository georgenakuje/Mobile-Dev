import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'event.dart';

Future<List<Event>> importIcsFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['ics'],
  );

  if (result == null || result.files.single.path == null) {
    return [];
  }

  final file = File(result.files.single.path!);
  final content = await file.readAsString();

  final calendar = ICalendar.fromString(content);
  final events = <Event>[];

  for (final e in calendar.data) {
    try {
      // Safely extract dtstart and dtend from the IcsDateTime object
      DateTime? start;
      DateTime? end;

      final rawStart = e['dtstart'];
      final rawEnd = e['dtend'];

      if (rawStart is IcsDateTime) {
        start = rawStart.toDateTime();
      } else if (rawStart is String) {
        start = DateTime.tryParse(rawStart);
      }

      if (rawEnd is IcsDateTime) {
        end = rawEnd.toDateTime();
      } else if (rawEnd is String) {
        end = DateTime.tryParse(rawEnd);
      }

      events.add(
        Event(
          id: (e['uid'] ?? DateTime.now().microsecondsSinceEpoch.toString()),
          title: e['summary'] ?? 'Untitled Event',
          description: e['description'] ?? '',
          startTime: start ?? DateTime.now(),
          endTime: end ?? (start?.add(const Duration(hours: 1)) ?? DateTime.now()),
          location: e['location'] ?? '',
        ),
      );
    } catch (err, st) {
      print('⚠️ Error parsing event: $err');
      print(st);
    }
  }

  return events;
}
