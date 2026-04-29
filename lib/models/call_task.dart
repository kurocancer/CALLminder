import 'dart:convert';

class CallTask {
  String task;
  DateTime dateTime;
  int snooze;
  String repeatMode;
  List<int> customDays;
  int? notificationId;
  String? details;

  CallTask(
    this.task,
    this.dateTime,
    this.snooze,
    this.repeatMode,
    this.customDays, {
    this.notificationId,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        "task": task,
        "dateTime": dateTime.toIso8601String(),
        "snooze": snooze,
        "repeatMode": repeatMode,
        "customDays": customDays,
        "notificationId": notificationId,
        "details": details,
      };

  factory CallTask.fromJson(Map<String, dynamic> json) {
    return CallTask(
      json["task"],
      DateTime.parse(json["dateTime"]),
      json["snooze"] ?? 0,
      json["repeatMode"] ?? 'none',
      List<int>.from(json["customDays"] ?? []),
      notificationId: json["notificationId"],
      details: json["details"],
    );
  }

  DateTime calculateNextTime() {
    DateTime now = DateTime.now();
    DateTime next = dateTime;

    if (repeatMode == 'daily') {
      next = next.add(Duration(days: 1));
      while (next.isBefore(now)) next = next.add(Duration(days: 1));
    } else if (repeatMode == 'weekly') {
      next = next.add(Duration(days: 7));
      while (next.isBefore(now)) next = next.add(Duration(days: 7));
    } else if (repeatMode == 'custom' && customDays.isNotEmpty) {
      next = next.add(Duration(days: 1));
      while (next.isBefore(now) || !customDays.contains(next.weekday)) {
        next = next.add(Duration(days: 1));
      }
    }
    return next;
  }
}
