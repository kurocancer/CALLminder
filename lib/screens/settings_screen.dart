import 'package':flutter/material.dart';
import 'package':shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'dark';
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _themeMode = prefs.getString('theme_mode') ?? 'dark';
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('tasks') ?? [];
    if (mounted) {
      setState(() {
        _history = data
            .map((e) => jsonDecode(e) as Map<String, dynamic>)
            .where((task) => task['completed'] == true)
            .toList();
      });
    }
  }

  Future<void> _setTheme(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode);
      if (mounted) {
        setState(() => _themeMode = mode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Theme updated!')),
        );
      }
    } catch (e) {
      print("Error saving theme: $e");
    }
  }

  Future<void> _clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Re-load tasks, remove completed ones
      final tasks = prefs.getStringList('tasks') ?? [];
      final active = tasks.where((e) {
        final task = jsonDecode(e);
        return task['completed'] != true;
      }).toList();
      await prefs.setStringList('tasks', active);
      if (mounted) {
        setState(() => _history.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('History cleared!')),
        );
      }
    } catch (e) {
      print("Error clearing history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Theme Section
          Text(
            'App Theme',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _themeMode,
              isExpanded: true,
              dropdownColor: Color(0xFF1A1A1A),
              underline: SizedBox(),
              style: TextStyle(color: Colors.white),
              items: ['dark', 'light'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value.capitalize(),
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null && mounted) {
                  _setTheme(newValue);
                }
              },
            ),
          ),
          SizedBox(height: 30),

          // Reminder History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminder History (Completed)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          _history.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No completed reminders yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final task = _history[index];
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text(
                          task['task'] ?? 'Unknown',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${task['dateTime']?.split(" ")[0] ?? 'No date'}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
