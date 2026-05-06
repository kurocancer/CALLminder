import 'package:flutter/material.dart';
import '../models/call_task.dart';
import '../notification_service.dart';
import '../services/auth_service.dart';
import 'classic_callminder_form.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomeDashboard extends StatefulWidget {
  @override
  _HomeDashboardState createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  List<CallTask> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("tasks");
    if (data != null && mounted) {
      setState(() {
        tasks = data.map((e) => CallTask.fromJson(jsonDecode(e))).toList();
      });
    }
  }

  String _getTimeUntilNext() {
    if (tasks.isEmpty) return "No tasks";
    tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final next = tasks.first;
    final diff = next.dateTime.difference(DateTime.now());
    if (diff.isNegative) return "Overdue!";
    return "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
  }

  void _deleteTask(int index) async {
    setState(() => tasks.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      "tasks",
      tasks.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Color(0xFF1A1A1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF00D4FF)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF00D4FF)),
                ),
                SizedBox(height: 10),
                Text(
                  AuthService().currentUser?.displayName ?? 'User',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  AuthService().currentUser?.email ?? '',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text('User Profile', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.white),
            title: Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications, color: Colors.white),
            title: Text('Notification Settings', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationSettingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.security, color: Colors.white),
            title: Text('App Permissions', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Open app permissions
            },
          ),
          Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('CALLMINDER'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next task in',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  _getTimeUntilNext(),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D4FF),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'No Callminders yet!\nTap AI tab to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFF00D4FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            task.task,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${task.dateTime.toString().split(" ")[0]} ${TimeOfDay.fromDateTime(task.dateTime).format(context)}',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () async {
              // Test notification in 10 seconds
              final testTask = CallTask(
                "Test Task",
                DateTime.now().add(Duration(seconds: 10)),
                0,
                "none",
                [],
                details: "This is a test",
              );
              await NotificationService.scheduleCall(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                title: "CALLMINDER TEST",
                body: "Test notification",
                scheduledTime: DateTime.now().add(Duration(seconds: 10)),
                payload: jsonEncode(testTask.toJson()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Test notification in 10 seconds')),
              );
            },
            backgroundColor: Colors.green,
            child: Icon(Icons.notifications_active),
            heroTag: "test_notif",
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClassicCallminderForm()),
              ).then((_) => _loadTasks());
            },
            backgroundColor: Color(0xFF00D4FF),
            child: Icon(Icons.add),
            heroTag: "add_task",
          ),
        ],
      ),
    );
  }
}
