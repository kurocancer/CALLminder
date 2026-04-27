import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'notification_service.dart';

class CallScreen extends StatefulWidget {
  final String task;
  final int snoozeMinutes;

  CallScreen({required this.task, required this.snoozeMinutes});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final player = AudioPlayer();
  final tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    player.setReleaseMode(ReleaseMode.loop);
    player.play(AssetSource('ringtone.mp3'));
  }

  @override
  void dispose() {
    player.stop();
    tts.stop();
    super.dispose();
  }

  // Phase 4: Renamed from hangUpAndSnooze to just snoozeCall
  void snoozeCall() async {
    player.stop();

    int selectedMinutes = widget.snoozeMinutes;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Snooze Duration"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("$selectedMinutes minutes"),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: "$selectedMinutes",
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedMinutes = value.toInt();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Snooze"),
            ),
          ],
        );
      },
    );

    final newTime = DateTime.now().add(Duration(minutes: selectedMinutes));

    NotificationService.scheduleCall(
      id: DateTime.now().millisecondsSinceEpoch,
      title: "Callminder (Snoozed)",
      body: widget.task,
      scheduledTime: newTime,
    );

    Navigator.pop(context);
  }

  void acceptCall() async {
    player.stop();
    await tts.speak("Hey, you still haven't ${widget.task}");
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
              // Phase 4: Button logic mapped to snoozeCall
              Column(
                children: [
                  GestureDetector(
                    onTap: snoozeCall,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.red,
                      child: Icon(
                        Icons.snooze,
                        color: Colors.white,
                      ), // Changed icon to snooze
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

          ElevatedButton(
            onPressed: () async {
              await tts.speak("Good job. Task completed.");
              Navigator.pop(context);
            },
            child: Text("Mark as Done"),
          ),
        ],
      ),
    );
  }
}
