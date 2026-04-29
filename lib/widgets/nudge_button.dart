import 'package:flutter/material.dart';
import 'dart:async';
import '../services/nudge_service.dart';

class NudgeButton extends StatefulWidget {
  final String friendId;
  final String friendName;

  NudgeButton({required this.friendId, required this.friendName});

  @override
  _NudgeButtonState createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<NudgeButton> {
  bool _isOnCooldown = false;
  int _cooldownSeconds = 0;
  Timer? _timer;

  Future<void> _handleNudge() async {
    final nudgeService = NudgeService();
    final result = await nudgeService.canSendNudge(widget.friendId);

    if (!result.allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
      return;
    }

    String? message = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController nudgeController = TextEditingController();
        return AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
           title: Text('Nudge ${widget.friendName}',
               style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
      bool sent = await nudgeService.sendNudge(
          widget.friendId, widget.friendName, message);
      if (sent && mounted) {
        setState(() {
          _isOnCooldown = true;
          _cooldownSeconds = 1800;
        });

        _timer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _cooldownSeconds--);
            if (_cooldownSeconds <= 0) {
              setState(() => _isOnCooldown = false);
              timer.cancel();
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nudge sent!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _isOnCooldown
            ? LinearGradient(colors: [Colors.grey, Colors.grey])
            : LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFFB400FF)],
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton(
        onPressed: _isOnCooldown ? null : _handleNudge,
        child: Text(
          _isOnCooldown
              ? "Cooldown: ${_cooldownSeconds ~/ 60}m"
              : "NUDGE",
           style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
