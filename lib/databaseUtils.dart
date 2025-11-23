import 'dart:collection';
import 'package:table_calendar/table_calendar.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'event.dart';
import 'package:rrule/rrule.dart';

final kToday = DateTime.now();
final kFirstDay = DateTime(1900, 1, 1);
final kLastDay = DateTime(2100, 12, 31);

int getHashCode(DateTime key) =>
    key.day * 1000000 + key.month * 10000 + key.year;

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

// --- Database Helper Class ---

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String tableName = 'events';
  static const String databaseName = 'event_database_6.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // This function is called when the database is created for the first time.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      description TEXT,
      startTime INTEGER,   -- The start of the very first event                                          ****STORED AS LOCAL TIME****
      endTime INTEGER,     -- The end of the very first event                                            ****STORED AS LOCAL TIME****
      rrule TEXT,           -- "" for single events. Example: "FREQ=WEEKLY;BYDAY=MO"                     ****SHOULD BE STORED AS UTC****
      parentId INTEGER,    -- -1 if this is a new event. ID of parent if this is an exception.
      exdate TEXT           -- Comma separated list of dates to exclude (cancelled instances)            ****SHOULD BE STORED AS UTC****
    )''');

    // Add initial hardcoded entries
    final initialEvents = [
      Event(
        title: 'Meeting (Default)',
        startTime: DateTime(kToday.year, kToday.month, kToday.day, 9, 0),
        endTime: DateTime(kToday.year, kToday.month, kToday.day, 10, 0),
        description: "Added by default",
        exdate: "EXDATE:20251206T000000Z",
        parentId: -1,
        rrule: 'RRULE:FREQ=WEEKLY;INTERVAL=2;UNTIL=20260201T000000Z',
      ),
    ];

    final batch = db.batch();
    for (var event in initialEvents) {
      batch.insert(tableName, event.excludePrimaryKeyMap());
    }
    await batch.commit(noResult: true);
  }

  // CRUD Operation: Insert a new event
  Future<int> insertEvent(Event event) async {
    final db = await database;
    return await db.insert(
      tableName,
      event.excludePrimaryKeyMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all events
  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    // Convert List<Map<String, dynamic>> to List<Event>
    return List.generate(maps.length, (i) {
      return Event.fromJson(maps[i]);
    });
  }

  // Get all events in range
  Future<List<DisplayEvent>> getEventsForRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> events = await db.rawQuery(
      '''
      SELECT * FROM events 
      -- Case 1: Non-recurring events must be strictly within the window
      WHERE (rrule IS NULL AND startTime BETWEEN ? AND ?)

      OR 

      -- Case 2: Recurring events. We fetch them all because we don't know 
      -- if they are finished or still active without parsing the RRule.
      (rrule IS NOT NULL)
    ''',
      [rangeStart.toIso8601String(), rangeEnd.toIso8601String()],
    );

    List<DisplayEvent> displayEvents = [];

    for (var event in events) {
      final rruleString = event['rrule'] as String?;
      final exdateString = event['exdate'] as String?;

      if (rruleString == null) {
        // --- HANDLE NON-RECURRING ---
        displayEvents.add(
          DisplayEvent(
            id: event['id'],
            title: event['title'],
            description: event['description'],
            startTime: DateTime.parse(event['startTime']),
            endTime: DateTime.parse(event['endTime']),
            parentId: event['parentId'],
          ),
        );
      } else {
        // --- HANDLE RECURRING ---

        final Set<DateTime> exceptionDates = _parseExDates(exdateString);
        final rrule = RecurrenceRule.fromString(rruleString);
        final eventStart = DateTime.parse(event['startTime']);
        final originalEnd = DateTime.parse(event['endTime']);

        final instances = rrule.getInstances(start: eventStart.toUtc());

        // 3. Calculate Duration to determine EndTime for each instance
        final Duration eventDuration = originalEnd.difference(eventStart);

        for (var instanceDate in instances) {
          // 4. CHECK EXCLUSION
          bool isExcluded = exceptionDates.any(
            (ex) =>
                ex.year == instanceDate.year &&
                ex.month == instanceDate.month &&
                ex.day == instanceDate.day,
          );

          if (isExcluded) {
            continue; // Skip this instance
          }

          final instanceEnd = instanceDate.add(eventDuration);

          // 5. Add to display list (Converting back to Local time for UI)
          displayEvents.add(
            DisplayEvent(
              id: event['id'],
              title: event['title'],
              startTime: instanceDate.toLocal(),
              endTime: instanceEnd.toLocal(),
              description: event['description'],
              parentId: event['parentId'],
            ),
          );
        }
      }
    }
    return displayEvents;
  }

  /// Parses an .ics EXDATE string into a Set of DateTime objects.
  /// Handles:
  /// 1. "EXDATE:" prefixes
  /// 2. Comma-separated values
  /// 3. Compact ISO format (20230101T120000Z)
  /// 4. Standard ISO format (2023-01-01T12:00:00Z)
  Set<DateTime> _parseExDates(String? exdateString) {
    if (exdateString == null || exdateString.isEmpty) return {};

    final Set<DateTime> exDates = {};

    // Remove "EXDATE:" prefix if present and trim whitespace
    String cleanString = exdateString
        .replaceAll(RegExp(r'^EXDATE:', caseSensitive: false), '')
        .trim();

    // Split by comma
    List<String> rawDates = cleanString.split(',');

    for (String rawDate in rawDates) {
      try {
        String isoDate = rawDate.trim();

        // Fix Compact ISO format (YYYYMMDDTHHMMSSZ) to Dart-friendly ISO (YYYY-MM-DDTHH:MM:SSZ)
        // Only applies if it matches the compact pattern
        if (RegExp(r'^\d{8}T\d{6}Z?$').hasMatch(isoDate)) {
          isoDate =
              "${isoDate.substring(0, 4)}-${isoDate.substring(4, 6)}-${isoDate.substring(6, 8)}"
              "T${isoDate.substring(9, 11)}:${isoDate.substring(11, 13)}:${isoDate.substring(13)}";
        }

        // Parse and force UTC to match the RRule instances
        exDates.add(DateTime.parse(isoDate).toUtc());
      } catch (e) {
        print("Error parsing exdate: $rawDate - $e");
      }
    }

    return exDates;
  }
}

Future<LinkedHashMap<DateTime, List<DisplayEvent>>>
getEventsFromDatabase() async {
  final dbHelper = DatabaseHelper();
  final allEvents = await dbHelper.getEventsForRange(
    DateTime.now().subtract(Duration(days: 365)),
    DateTime.now().add(Duration(days: 365)),
  );

  final eventsMap = LinkedHashMap<DateTime, List<DisplayEvent>>(
    equals: isSameDay,
    hashCode: getHashCode,
  );

  for (var event in allEvents) {
    final day = _d(event.startTime);
    if (eventsMap[day] == null) {
      eventsMap[day] = [];
    }
    eventsMap[day]!.add(event);
  }

  return eventsMap;
}
