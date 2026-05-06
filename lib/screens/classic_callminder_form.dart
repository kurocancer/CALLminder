import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/call_task.dart';
import '../notification_service.dart';

class ClassicCallminderForm extends StatefulWidget {
  @override
  _ClassicCallminderFormState createState() => _ClassicCallminderFormState();
}

class _ClassicCallminderFormState extends State<ClassicCallminderForm> {
  final _taskController = TextEditingController();
  final _detailsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _repeat = 'none';

  final List<String> _repeatOptions = ['none', 'daily', 'weekly', 'custom'];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveTask() async {
    if (_taskController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a task name')),
      );
      return;
    }

    try {
      final taskDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final task = CallTask(
        _taskController.text,
        taskDateTime,
        0,
        _repeat,
        [],
        details: _detailsController.text.isEmpty ? null : _detailsController.text,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      task.notificationId = notificationId;

      await NotificationService.scheduleCall(
        id: notificationId,
        title: "CALLMINDER",
        body: task.task,
        scheduledTime: taskDateTime,
        payload: jsonEncode(task.toJson()),
      );

      final prefs = await SharedPreferences.getInstance();
      List<String> tasks = prefs.getStringList("tasks") ?? [];
      tasks.add(jsonEncode(task.toJson()));
      await prefs.setStringList("tasks", tasks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task "${task.task}" scheduled!')),
        );
        Navigator.pop(context, true); // Return true to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('New Callminder'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Name',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _taskController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter task name...',
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Details (Optional)',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add details...',
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Date',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(Icons.calendar_today, color: Color(0xFF00D4FF)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Time',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTime.format(context),
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(Icons.access_time, color: Color(0xFF00D4FF)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Repeat',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _repeat,
                isExpanded: true,
                dropdownColor: Color(0xFF1A1A1A),
                underline: SizedBox(),
                style: TextStyle(color: Colors.white),
                items: _repeatOptions.map((String value) {
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
                    setState(() => _repeat = newValue);
                  }
                },
              ),
            ),
            SizedBox(height: 40),

            Center(
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00D4FF),
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Save Task',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
