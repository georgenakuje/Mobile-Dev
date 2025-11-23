import 'dart:collection';
import 'package:table_calendar/table_calendar.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'event.dart';

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
  static const String databaseName = 'event_database_2.db';

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
      startTime INTEGER,   -- The start of the very first event
      endTime INTEGER,     -- The end of the very first event
      rrule TEXT,           -- "" for single events. Example: "FREQ=WEEKLY;BYDAY=MO"
      parentId INTEGER,    -- -1 if this is a new event. ID of parent if this is an exception.
      exdate TEXT           -- Comma separated list of dates to exclude (cancelled instances)
    )''');

    // Add initial hardcoded entries
    final initialEvents = [
      Event(
        title: 'Meeting (Default)',
        startTime: DateTime(kToday.year, kToday.month, kToday.day, 9, 0),
        endTime: DateTime(kToday.year, kToday.month, kToday.day, 10, 0),
        description: "Added by default",
        exdate: "",
        parentId: -1,
        rrule: 'RRULE:INTERVAL=2;FREQ=WEEKLY',
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
}

Future<LinkedHashMap<DateTime, List<Event>>> getEventsFromDatabase() async {
  final dbHelper = DatabaseHelper();
  final allEvents = await dbHelper.getAllEvents();

  final eventsMap = LinkedHashMap<DateTime, List<Event>>(
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
