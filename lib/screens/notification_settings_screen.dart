import 'package':flutter/material.dart';
import 'package':shared_preferences/shared_preferences.dart';
import 'package':audioplayers/audioplayers.dart';
import '../services/auth_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  int _snoozeDuration = 15; // Default 15 minutes
  String _selectedRingtone = 'ringtone.mp3';
  List<String> _availableRingtones = ['ringtone.mp3', 'alert.mp3', 'chime.mp3'];
  AudioPlayer _audioPlayer = AudioPlayer();

  @override,
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _snoozeDuration = prefs.getInt('default_snooze_duration') ?? 15;
          _selectedRingtone = prefs.getString('selected_ringtone') ?? 'ringtone.mp3';
        });
      }
    } catch (e) {
      print("Error loading notification settings: $e");
    }
  }

  Future<void> _saveSnoozeDuration(int duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('default_snooze_duration', duration);
      if (mounted) {
        setState(() => _snoozeDuration = duration);
        // Also update CallTask default
        CallTask.defaultSnoozeMinutes = duration;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snooze duration updated!')),
        );
      }
    } catch (e) {
      print("Error saving snooze duration: $e");
    }
  }

  Future<void> _saveRingtone(String ringtone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_ringtone', ringtone);
      if (mounted) {
        setState(() => _selectedRingtone = ringtone);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ringtone updated!')),
        );
      }
    } catch (e) {
      print("Error saving ringtone: $e");
    }
  }

  Future<void> _previewRingtone(String ringtone) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(ringtone));
    } catch (e) {
      print("Error playing ringtone: $e");
    }
  }

  Future<void> _openAppSettings() async {
    try {
      // Use permission_handler or url_launcher to open app settings
      // For now, show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please open app settings manually to manage permissions')),
        );
      }
    } catch (e) {
      print("Error opening settings: $e");
    }
  }

  @override,
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Default Snooze Duration',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<int>(
              value: _snoozeDuration,
              isExpanded: true,
              dropdownColor: Color(0xFF1A1A1A),
              underline: SizedBox(),
              style: TextStyle(color: Colors.white),
              items: [5, 10, 15, 30, 60].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    '$value minutes',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null && mounted) {
                  _saveSnoozeDuration(newValue);
                }
              },
            ),
          ),
          SizedBox(height: 30),

          Text(
            'Default Ringtone',
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
              value: _selectedRingtone,
              isExpanded: true,
              dropdownColor: Color(0xFF1A1A1A),
              underline: SizedBox(),
              style: TextStyle(color: Colors.white),
              items: _availableRingtones.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value.replaceAll('.mp3', '').capitalize(),
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null && mounted) {
                  _saveRingtone(newValue);
                }
              },
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _previewRingtone(_selectedRingtone),
              icon: Icon(Icons.play_arrow, color: Colors.white),
              label: Text('Preview Ringtone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00D4FF),
              ),
            ),
          ),
          SizedBox(height: 30),

          Text(
            'App Permissions',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.settings, color: Colors.white),
              title: Text(
                'Manage App Permissions',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Notifications, Microphone, Storage',
                style: TextStyle(color: Colors.grey),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _openAppSettings,
            ),
          ),
        ],
      ),
    );
  }

  @override,
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
