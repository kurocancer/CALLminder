import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class AIService {
  static const String _modelName = 'gemini-1.5-flash';
  late GenerativeModel _model;
  late ChatSession _chat;

  Future<void> init(String apiKey) async {
    _model = GenerativeModel(model: _modelName, apiKey: apiKey);
    _chat = _model.startChat();
  }

  Future<String> generateGreeting({
    required String task,
    String? details,
    required String userName,
    required String timeOfDay,
  }) async {
    final prompt = '''
You are a reminder assistant for $userName.
Time of day: $timeOfDay
Task: $task
${details != null && details.isNotEmpty ? "Details: $details" : ""}

Greet the user warmly based on time of day. Mention the task${details != null && details.isNotEmpty ? ' and the details' : ''}.
Then ask: "Have you completed this task, or should I snooze it?"
Keep response under 40 words. Be conversational.
''';
    final response = await _chat.sendMessage(Content.text(prompt));
    return response.text ?? "Hello! You have a reminder: $task";
  }

  Future<String> processResponse(String userSpeech) async {
    final prompt = '''
User said: "$userSpeech"

Task context: Determine user's intent:
- If user clearly completed task → reply exactly "ACTION: DONE"
- If user wants to snooze/postpone/delay → reply exactly "ACTION: SNOOZE"
- If unclear or user asks to repeat → reply exactly "ACTION: UNCLEAR" and ask them to clarify

Reply with ONLY the ACTION line, nothing else.
''';
    final response = await _chat.sendMessage(Content.text(prompt));
    return response.text ?? "ACTION: UNCLEAR";
  }

  Future<String> processNaturalLanguage(String prompt) async {
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "{}";
    } catch (e) {
      print("Natural language processing error: $e");
      return "{}";
    }
  }
}
