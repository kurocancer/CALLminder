import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';
import 'main.dart'; // Import to use CallTask logic

class CallScreen extends StatefulWidget {
  final String payload;

  CallScreen({required this.payload});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final player = AudioPlayer();
  final tts = FlutterTts();
  late CallTask currentTask;

  @override
  void initState() {
    super.initState();
    // Decode the rules we packed inside main.dart
    currentTask = CallTask.fromJson(jsonDecode(widget.payload));

    player.setReleaseMode(ReleaseMode.loop);
    player.play(AssetSource('ringtone.mp3'));
  }

  @override
  void dispose() {
    player.stop();
    tts.stop();
    super.dispose();
  }

  void snoozeCall() async {
    player.stop();

    final prefs = await SharedPreferences.getInstance();
    int snoozeDuration = prefs.getInt("default_snooze") ?? 10;

    final newTime = DateTime.now().add(Duration(minutes: snoozeDuration));

    // THE SHADOW ALARM: Schedule a one-off native alarm for the snooze.
    // We DO NOT update the main task in the SharedPreferences database.
    // This perfectly protects your everyday routine!
    NotificationService.scheduleCall(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: "Callminder (Snoozed)",
      body: currentTask.task,
      scheduledTime: newTime,
      payload: widget.payload, // Pass the exact same package back in
    );

    Navigator.pop(context);
  }

  void acceptCall() async {
    player.stop();
    await tts.speak("Good job. Task completed.");

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedData = prefs.getStringList("tasks") ?? [];
      List<CallTask> allTasks = savedData
          .map((e) => CallTask.fromJson(jsonDecode(e)))
          .toList();

      // Find and remove the current version of the task
      allTasks.removeWhere((t) => t.task == currentTask.task);

      // If it repeats, rebuild it and put it back in!
      if (currentTask.repeatMode != 'none') {
        DateTime nextTime = currentTask.calculateNextTime();
        currentTask.dateTime = nextTime;

        allTasks.add(currentTask);

        // Schedule the next master alarm
        NotificationService.scheduleCall(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: "Callminder",
          body: currentTask.task,
          scheduledTime: nextTime,
          payload: jsonEncode(currentTask.toJson()),
        );
      }

      // Save the fresh database
      await prefs.setStringList(
        "tasks",
        allTasks.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      print("Error processing task completion: $e");
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Callminder",
            style: TextStyle(color: Colors.white, fontSize: 28),
          ),
          SizedBox(height: 20),
          Text("Incoming Call...", style: TextStyle(color: Colors.grey)),
          SizedBox(height: 60),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  GestureDetector(
                    onTap: snoozeCall,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.snooze, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Snooze", style: TextStyle(color: Colors.white)),
                ],
              ),

              Column(
                children: [
                  GestureDetector(
                    onTap: acceptCall,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.call, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Answer", style: TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),

          SizedBox(height: 40),

          ElevatedButton(onPressed: acceptCall, child: Text("Mark as Done")),
        ],
      ),
    );
  }
}
