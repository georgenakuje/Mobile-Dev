import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final int? id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? rrule;
  final int parentId;
  final String? exdate;

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.rrule,
    required this.parentId,
    required this.exdate,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  Map<String, dynamic> excludePrimaryKeyMap() => <String, dynamic>{
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'rrule': rrule,
    'parentId': parentId,
    'exdate': exdate,
  };
}
