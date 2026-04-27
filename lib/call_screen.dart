import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'dart:async';
import 'notification_service.dart';
import 'main.dart';
import 'ai_service.dart';

class CallScreen extends StatefulWidget {
  final String payload;

  CallScreen({required this.payload});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final player = AudioPlayer();
  final tts = FlutterTts();
  CallTask? currentTask;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AIService _aiService = AIService();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _isAiInitialized = false;
  bool _isApiKeyLoaded = false;
  String? _userName;
  String? _geminiApiKey;
  Timer? _autoSnoozeTimer;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _startAutoSnoozeTimer();
  }

  void _initializeCall() async {
    try {
      currentTask = CallTask.fromJson(jsonDecode(widget.payload));
    } catch (e) {
      print("Error parsing payload: $e");
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    player.setReleaseMode(ReleaseMode.loop);
    player.play(AssetSource('ringtone.mp3'));
    _cancelTriggeringNotification();
    await _loadApiKey();
    _initializeTts();
  }

  void _cancelTriggeringNotification() async {
    try {
      final data = jsonDecode(widget.payload);
      int? id = data['notificationId'];
      if (id != null) {
        await NotificationService.cancelNotification(id);
      }
    } catch (_) {}
  }

  void _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString("username");
    _geminiApiKey = prefs.getString("gemini_api_key");

    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      _geminiApiKey = "AIzaSyAB-ys0uexYtCcv514XKihkBCWizxwbjp4";
      await prefs.setString("gemini_api_key", _geminiApiKey!);
    }

    if (mounted) {
      setState(() => _isApiKeyLoaded = true);
    }
  }

  void _initializeTts() async {
    try {
      await tts.awaitSpeakCompletion(true);
      var languages = await tts.getLanguages;
      print("Available TTS languages: $languages");
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  void _startAutoSnoozeTimer() {
    _autoSnoozeTimer = Timer(Duration(minutes: 2), () {
      if (mounted) {
        snoozeCall();
      }
    });
  }

  void _startConversation() async {
    if (!_isApiKeyLoaded) {
      if (mounted) {
        await tts.speak("Please wait, initializing...");
      }
      return;
    }

    if (_isListening || _isProcessing || _isSpeaking) return;

    try {
      if (!_isAiInitialized && _geminiApiKey != null) {
        await _aiService.init(_geminiApiKey!);
        _isAiInitialized = true;
      }

      setState(() {
        _isSpeaking = true;
        _isListening = false;
        _isProcessing = false;
      });

      player.stop();

      final hour = DateTime.now().hour;
      String timeOfDay =
          hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening";

      if (currentTask == null) return;

      String greeting = await _aiService.generateGreeting(
        task: currentTask!.task,
        details: currentTask!.details,
        userName: _userName ?? "there",
        timeOfDay: timeOfDay,
      );

      await tts.speak(greeting);
      await Future.delayed(Duration(seconds: 3));
      _startListening();
    } catch (e) {
      print("AI Error: $e");
      if (mounted) {
        await tts.speak(
          "Sorry, I'm having trouble. Please use the buttons below.",
        );
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  void _startListening() async {
    if (!mounted || currentTask == null) return;

    try {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (!available) {
        if (mounted) {
          await tts.speak("Microphone not available. Please use the buttons.");
          setState(() {
            _isSpeaking = false;
            _isListening = false;
          });
        }
        return;
      }

      setState(() {
        _isListening = true;
        _isSpeaking = false;
      });

      _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _processUserSpeech(result.recognizedWords);
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
        ),
      );
    } catch (e) {
      print("Speech error: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
          _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _processUserSpeech(String speech) async {
    if (!mounted || currentTask == null) return;

    _speech.stop();
    _autoSnoozeTimer?.cancel();

    setState(() {
      _isListening = false;
      _isProcessing = true;
    });

    try {
      final response = await _aiService.processResponse(speech);
      print("AI Response: $response");

      if (response.contains("DONE")) {
        await tts.speak("Great job! Marking task as complete.");
        await Future.delayed(Duration(seconds: 2));
        acceptCall();
      } else if (response.contains("SNOOZE")) {
        await tts.speak("No problem. Snoozing the reminder.");
        await Future.delayed(Duration(seconds: 2));
        snoozeCall();
      } else {
        await tts.speak(
          "I didn't catch that. Have you done it, or should I snooze it?",
        );
        await Future.delayed(Duration(seconds: 2));
        _startListening();
      }
    } catch (e) {
      print("Processing error: $e");
      if (mounted) {
        await tts.speak("Sorry, let's try again. Did you finish the task?");
        _startListening();
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void snoozeCall() async {
    if (currentTask == null) return;
    _autoSnoozeTimer?.cancel();
    player.stop();
    await WakelockPlus.disable();

    final prefs = await SharedPreferences.getInstance();
    int snoozeDuration = prefs.getInt("default_snooze") ?? 10;

    final newTime = DateTime.now().add(Duration(minutes: snoozeDuration));
    int newNotificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    currentTask!.dateTime = newTime;
    currentTask!.notificationId = newNotificationId;

    List<String> savedData = prefs.getStringList("tasks") ?? [];
    List<CallTask> allTasks =
        savedData.map((e) => CallTask.fromJson(jsonDecode(e))).toList();

    for (int i = 0; i < allTasks.length; i++) {
      if (allTasks[i].task == currentTask!.task) {
        allTasks[i] = currentTask!;
        break;
      }
    }

    await prefs.setStringList(
      "tasks",
      allTasks.map((e) => jsonEncode(e.toJson())).toList(),
    );

    NotificationService.scheduleCall(
      id: newNotificationId,
      title: "Callminder",
      body: currentTask!.task,
      scheduledTime: newTime,
      payload: jsonEncode(currentTask!.toJson()),
    );

    if (mounted) Navigator.pop(context);
  }

  void acceptCall() async {
    if (currentTask == null) return;
    _autoSnoozeTimer?.cancel();
    player.stop();
    await WakelockPlus.disable();

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedData = prefs.getStringList("tasks") ?? [];
      List<CallTask> allTasks =
          savedData.map((e) => CallTask.fromJson(jsonDecode(e))).toList();

      allTasks.removeWhere((t) => t.task == currentTask!.task);

      if (currentTask!.repeatMode != 'none') {
        DateTime nextTime = currentTask!.calculateNextTime();
        int newNotificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);

        currentTask!.dateTime = nextTime;
        currentTask!.notificationId = newNotificationId;

        allTasks.add(currentTask!);

        NotificationService.scheduleCall(
          id: newNotificationId,
          title: "Callminder",
          body: currentTask!.task,
          scheduledTime: nextTime,
          payload: jsonEncode(currentTask!.toJson()),
        );
      }

      await prefs.setStringList(
        "tasks",
        allTasks.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      print("Error processing task completion: $e");
    }

    if (mounted) Navigator.pop(context);
  }

  void _speakDetails() async {
    if (currentTask == null || _isListening || _isProcessing || _isSpeaking) return;

    setState(() => _isSpeaking = true);
    player.stop();

    String detailsText = currentTask!.details ?? "No details provided.";
    await tts.speak("Here are the details: $detailsText");
    await Future.delayed(Duration(seconds: 3));
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  void dispose() {
    _autoSnoozeTimer?.cancel();
    player.stop();
    tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentTask == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Error loading task", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    String statusText = "Incoming Call...";
    if (_isListening) statusText = "Listening...";
    if (_isProcessing) statusText = "Processing...";
    if (_isSpeaking) statusText = "Speaking...";

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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              currentTask!.task,
              style: TextStyle(color: Colors.white, fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 20),
          if (_isListening)
            Icon(Icons.mic, color: Colors.red, size: 50)
          else if (_isProcessing)
            CircularProgressIndicator(color: Colors.yellow)
          else if (_isSpeaking)
            Icon(Icons.volume_up, color: Colors.blue, size: 50),
          SizedBox(height: 40),
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
                      child: Icon(Icons.call_end, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Snooze", style: TextStyle(color: Colors.white)),
                ],
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: _startConversation,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.call, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Attend", style: TextStyle(color: Colors.white)),
                ],
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: acceptCall,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Done", style: TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
          SizedBox(height: 30),
          if (currentTask!.details != null && currentTask!.details!.isNotEmpty)
            TextButton(
              onPressed: _speakDetails,
              child: Text(
                "Details",
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
