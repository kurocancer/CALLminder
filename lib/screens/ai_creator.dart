import 'package:flutter/material.dart';
import '../models/call_task.dart';
import '../notification_service.dart';
import '../services/auth_service.dart';
import '../ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AICreator extends StatefulWidget {
  @override
  _AICreatorState createState() => _AICreatorState();
}

class _AICreatorState extends State<AICreator> {
  final TextEditingController _controller = TextEditingController();
  final AIService _aiService = AIService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<Map<String, String>> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  bool _isAiInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  Future<void> _initAI() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString("gemini_api_key");
      if (apiKey == null || apiKey.isEmpty) {
        apiKey = "AIzaSyAB-ys0uexYtCcv514XKihkBCWizxwbjp4";
        await prefs.setString("gemini_api_key", apiKey);
      }
      await _aiService.init(apiKey);
      _isAiInitialized = true;
    } catch (e) {
      print("AI init error: $e");
    }
  }

  Future<void> _processInput(String input) async {
    if (input.isEmpty || !_isAiInitialized) return;

    setState(() {
      _messages.add({'role': 'user', 'content': input});
      _isProcessing = true;
    });

    try {
      final prompt = '''
Parse this task request: "$input"

Extract the following and return ONLY as JSON:
{
  "task": "the task name",
  "time": "HH:MM" (24-hour format, use current time + 1 hour if not specified),
  "date": "YYYY-MM-DD" (today if not specified),
  "repeat": "none" | "daily" | "weekly" | "custom",
  "details": "any additional details"
}

If information is missing, use reasonable defaults.
Only return the JSON, nothing else.
''';

      final response = await _aiService.processNaturalLanguage('''
$prompt

User input: "$input"
''');
      final data = jsonDecode(response);

      final timeParts = (data['time'] as String).split(':');
      final dateParts = (data['date'] as String).split('-');

      final task = CallTask(
        data['task'],
        DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        ),
        0,
        data['repeat'],
        [],
        details: data['details'],
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      task.notificationId = notificationId;

      await NotificationService.scheduleCall(
        id: notificationId,
        title: "CALLMINDER",
        body: task.task,
        scheduledTime: task.dateTime,
        payload: jsonEncode(task.toJson()),
      );

      final prefs = await SharedPreferences.getInstance();
      List<String> tasks = prefs.getStringList("tasks") ?? [];
      tasks.add(jsonEncode(task.toJson()));
      await prefs.setStringList("tasks", tasks);

      setState(() {
        _messages.add({
          'role': 'ai',
          'content': 'Task "${data['task']}" scheduled for ${data['time']}!'
        });
        _controller.clear();
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'content': 'Sorry, I had trouble understanding that. Please try again.'
        });
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _startListening() async {
    try {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          if (result.finalResult) {
            setState(() {
              _controller.text = result.recognizedWords;
              _isListening = false;
            });
          }
        });
      }
    } catch (e) {
      print("Speech error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('AI Creator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Color(0xFF00D4FF).withOpacity(0.2)
                          : Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser
                            ? Color(0xFF00D4FF)
                            : Colors.grey.shade800!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isProcessing)
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(Color(0xFF00D4FF)),
            ),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.grey.shade800!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Color(0xFF00D4FF),
                  ),
                  onPressed: _startListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type or speak your task...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _processInput,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Color(0xFF00D4FF)),
                  onPressed: () => _processInput(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
