import 'dart:collection';
import 'package:table_calendar/table_calendar.dart';

class Event {
  final String title;
  final DateTime start;
  final DateTime end;
  const Event(this.title, this.start, this.end);
  @override
  String toString() => title;
}

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);

int getHashCode(DateTime key) => key.day * 1000000 + key.month * 10000 + key.year;

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
)..addAll({
  _d(kToday): [
    Event('Meeting', DateTime(kToday.year, kToday.month, kToday.day, 9, 0),
        DateTime(kToday.year, kToday.month, kToday.day, 10, 0)),
    Event('Lunch', DateTime(kToday.year, kToday.month, kToday.day, 12, 30),
        DateTime(kToday.year, kToday.month, kToday.day, 13, 30)),
  ],
  _d(kToday.add(const Duration(days: 1))): [
    Event('Workout', DateTime(kToday.year, kToday.month, kToday.day + 1, 18, 0),
        DateTime(kToday.year, kToday.month, kToday.day + 1, 19, 0)),
  ],
  _d(kToday.subtract(const Duration(days: 1))): [
    Event('Study', DateTime(kToday.year, kToday.month, kToday.day - 1, 16, 0),
        DateTime(kToday.year, kToday.month, kToday.day - 1, 17, 30)),
  ],
});
