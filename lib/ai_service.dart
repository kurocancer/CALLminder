import 'package':google_generative_ai/google_generative_ai.dart';
import 'dart':convert';

class AIService {
  static const String _modelName = 'gemini-1.0-pro';
  late GenerativeModel _model;
  late ChatSession _chat;

  Future<void> init(String apiKey) async {
    try {
      print("=== AI DEBUG: Initializing with API key: ${apiKey.substring(0, 10)}...");
      _model = GenerativeModel(model: _modelName, apiKey: apiKey);
      _chat = _model.startChat();
      print("AI service initialized successfully");
    } catch (e) {
      print("=== AI ERROR: Initialization failed: $e");
    }
  }

  Future<String> generateGreeting({
    required String task,
    String? details,
    required String userName,
    required String timeOfDay,
  }) async {
    try {
      final prompt = '''
You are a reminder assistant for $userName.
Time of day: $timeOfDay
Task: $task
${details != null && details!.isNotEmpty ? "Details: $details" : ""}

Greet the user warmly based on time of day. Mention the task${details != null && details!.isNotEmpty ? ' and the details' : ''}.
Then ask: "Have you completed this task, or should I snooze it?"
Keep response under 40 words. Be conversational.
''';
      print("=== AI DEBUG: Sending greeting prompt for task: $task");
      final response = await _chat.sendMessage(Content.text(prompt));
      print("AI Response (greeting): ${response.text}");
      return response.text ?? "Hello! You have a reminder: $task";
    } catch (e) {
      print("=== AI ERROR: Greeting failed: $e");
      return "Hello! You have a reminder: $task";
    }
  }

  Future<String> processResponse(String userSpeech) async {
    try {
      final prompt = '''
User said: "$userSpeech"

Task context: Determine user's intent:
- If user clearly completed task → reply exactly "ACTION: DONE"
- If user wants to snooze/postpone/delay → reply exactly "ACTION: SNOOZE"
- If unclear or user asks to repeat → reply exactly "ACTION: UNCLEAR" and ask them to clarify

Reply with ONLY the ACTION line, nothing else.
''';
      print("=== AI DEBUG: Processing voice response: $userSpeech");
      final response = await _chat.sendMessage(Content.text(prompt));
      print("AI Response (processResponse): ${response.text}");
      return response.text ?? "ACTION: UNCLEAR";
    } catch (e) {
      print("=== AI ERROR: processResponse failed: $e");
      return "ACTION: UNCLEAR";
    }
  }

  Future<String> processNaturalLanguage(String prompt) async {
    try {
      print("=== AI DEBUG START ===");
      print("Prompt: $prompt");
      print("Model name: $_modelName");

      final response = await _model.generateContent([Content.text(prompt)]);
      
      print("Gemini raw response: ${response.text}");
      print("Finish reason: ${response.finishReason}");

      if (response.text == null || response.text!.isEmpty) {
        print("ERROR: Empty response from Gemini");
        return "{}";
      }

      // Try to parse as JSON
      try {
        final decoded = jsonDecode(response.text!);
        print("Parsed JSON: $decoded");
        return response.text!;
      } catch (e) {
        print("JSON parse error: $e");
        // Not valid JSON, return as-is
        return response.text!;
      }
    } catch (e, stackTrace) {
      print("=== AI DEBUG ERROR ===");
      print("Error: $e");
      print("StackTrace: $stackTrace");
      return "{}";
    }
  }
}
