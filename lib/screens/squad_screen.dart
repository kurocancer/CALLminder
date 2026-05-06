import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/nudge_button.dart';
import 'dart:async';

class SquadScreen extends StatefulWidget {
  @override
  _SquadScreenState createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  StreamSubscription? _friendsSub;
  StreamSubscription? _requestsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _friendsSub = _firestoreService.getFriends().listen((friends) {
      if (mounted) setState(() => _friends = friends);
    });

    _requestsSub = _firestoreService.getPendingRequests().listen((requests) {
      if (mounted) setState(() => _pendingRequests = requests);
    });
  }

  Future<void> _sendFriendRequest() async {
    String email = _emailController.text.trim();
    if (email.isEmpty) return;

    bool success = await _firestoreService.sendFriendRequest(email);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Friend request sent!' : 'User not found',
          ),
        ),
      );
      if (success) _emailController.clear();
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUserId) async {
    await _firestoreService.acceptFriendRequest(requestId, fromUserId);
  }

  Future<void> _sendNudge(String friendId, String friendName) async {
    String? message = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController nudgeController = TextEditingController();
        return AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          title: Text('Nudge $friendName', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nudgeController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your message...',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, nudgeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00D4FF),
              ),
              child: Text('NUDGE', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (message != null && message.isNotEmpty) {
      bool sent = await _firestoreService.sendNudge(friendId, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sent ? 'Nudge sent!' : 'Failed to send nudge')),
        );
      }
    }
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
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
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.white),
            title: Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.security, color: Colors.white),
            title: Text('App Permissions', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
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
        title: Text('The Squad'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_pendingRequests.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ...List.generate(_pendingRequests.length, (index) {
                    final request = _pendingRequests[index];
                    return ListTile(
                      title: Text(
                        request['fromName'] ?? 'Unknown',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptRequest(
                              request['id'],
                              request['fromUserId'],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Friend\'s email...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendFriendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00D4FF),
                  ),
                  child: Text('Add'),
                ),
              ],
            ),
          ),
          
          Divider(color: Colors.grey.shade800),
          
          Expanded(
            child: _friends.isEmpty
                ? Center(
                    child: Text(
                      'No friends yet.\nAdd some accountability partners!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFF00D4FF),
                          child: Text(
                            (friend['name'] as String? ?? '?').substring(0, 1),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          friend['name'] ?? 'Unknown',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: NudgeButton(
                          friendId: friend['uid'] ?? '',
                          friendName: friend['name'] ?? 'Unknown',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
