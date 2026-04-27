// SAME IMPORTS
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'call_screen.dart';
import 'notification_service.dart';
// ================= MAIN =================

void main() {
  runApp(RemindCallApp());
}

class RemindCallApp extends StatefulWidget {
  @override
  _RemindCallAppState createState() => _RemindCallAppState();
}

class _RemindCallAppState extends State<RemindCallApp> {
  ThemeMode themeMode = ThemeMode.system;
  String? userName;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  void loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userName = prefs.getString("username"));
  }

  void setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("username", name);
    setState(() => userName = name);
  }

  void changeTheme(ThemeMode mode) {
    setState(() => themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: userName == null
          ? CreateProfileScreen(onSave: setUserName)
          : HomeScreen(
              userName: userName!,
              onThemeChanged: changeTheme,
              onNameChanged: setUserName,
            ),
    );
  }
}

// ================= PROFILE SETUP =================

class CreateProfileScreen extends StatelessWidget {
  final Function(String) onSave;

  CreateProfileScreen({required this.onSave});

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController();

    return Scaffold(
      body: Center(
        child: Container(
          padding: EdgeInsets.all(25),
          margin: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Welcome to Callminder",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextField(controller: controller),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isEmpty) return;
                  onSave(controller.text);
                },
                child: Text("Start"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MODEL =================

class CallTask {
  String task;
  DateTime dateTime;
  int snooze;

  CallTask(this.task, this.dateTime, this.snooze);

  Map<String, dynamic> toJson() => {
    "task": task,
    "dateTime": dateTime.toIso8601String(),
    "snooze": snooze,
  };

  factory CallTask.fromJson(Map<String, dynamic> json) {
    return CallTask(
      json["task"],
      DateTime.parse(json["dateTime"]),
      json["snooze"],
    );
  }
}

// ================= HOME =================

class HomeScreen extends StatefulWidget {
  final String userName;
  final Function(ThemeMode) onThemeChanged;
  final Function(String) onNameChanged;

  HomeScreen({
    required this.userName,
    required this.onThemeChanged,
    required this.onNameChanged,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CallTask> tasks = [];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  void triggerCall(CallTask task) {
    final diff = task.dateTime.difference(DateTime.now());

    if (diff.isNegative) return;

    Future.delayed(diff, () {
      if (!mounted) return;

      // 🔥 REMOVE TASK AFTER TRIGGER
      setState(() {
        tasks.removeWhere(
          (t) => t.task == task.task && t.dateTime == task.dateTime,
        );
      });

      saveTasks();

      // 🔥 OPEN CALL SCREEN
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CallScreen(task: task.task, snoozeMinutes: task.snooze),
        ),
      );
    });
  }

  void saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      "tasks",
      tasks.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  void loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList("tasks");

    if (data != null) {
      setState(() {
        tasks = data.map((e) => CallTask.fromJson(jsonDecode(e))).toList();
      });
    }
  }

  void deleteTask(int index) {
    setState(() => tasks.removeAt(index));
    saveTasks();
  }

  void openTaskEditor({CallTask? existing, int? index}) async {
    TextEditingController controller = TextEditingController(
      text: existing?.task ?? "",
    );

    DateTime? date = existing?.dateTime;
    TimeOfDay? time = existing != null
        ? TimeOfDay.fromDateTime(existing.dateTime)
        : null;
    int snooze = existing?.snooze ?? 5;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: controller),

                  ListTile(
                    title: Text(
                      date == null
                          ? "Pick Date"
                          : date.toString().split(" ")[0],
                    ),
                    onTap: () async {
                      DateTime? d = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setStateSheet(() => date = d);
                    },
                  ),

                  ListTile(
                    title: Text(
                      time == null ? "Pick Time" : time!.format(context),
                    ),
                    onTap: () async {
                      TimeOfDay? t = await showTimePicker(
                        context: context,
                        initialTime: time ?? TimeOfDay.now(),
                      );
                      if (t != null) setStateSheet(() => time = t);
                    },
                  ),

                  DropdownButton<int>(
                    value: snooze,
                    items: [5, 10, 15, 30].map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text("$e min snooze"),
                      );
                    }).toList(),
                    onChanged: (v) => setStateSheet(() => snooze = v!),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.isEmpty ||
                          date == null ||
                          time == null)
                        return;

                      final dt = DateTime(
                        date!.year,
                        date!.month,
                        date!.day,
                        time!.hour,
                        time!.minute,
                      );

                      final newTask = CallTask(controller.text, dt, snooze);

                      setState(() {
                        if (existing == null) {
                          tasks.add(newTask);
                        } else {
                          tasks[index!] = newTask;
                        }
                      });

                      saveTasks();

                      triggerCall(newTask);

                      NotificationService.scheduleCall(
                        id: DateTime.now().millisecondsSinceEpoch,
                        title: "Callminder",
                        body: newTask.task,
                        scheduledTime: newTask.dateTime,
                      );

                      Navigator.pop(context);
                    },
                    child: Text("Save"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget taskCard(CallTask t, int i) {
    return Card(
      margin: EdgeInsets.all(10),
      child: ListTile(
        title: Text(t.task),
        subtitle: Text(
          "${t.dateTime.toString().split(" ")[0]} • ${TimeOfDay.fromDateTime(t.dateTime).format(context)}",
        ),
        leading: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => deleteTask(i),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => openTaskEditor(existing: t, index: i),
        ),
        onTap: () => openTaskEditor(existing: t, index: i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Callminder")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openTaskEditor(),
        child: Icon(Icons.add),
      ),

      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.userName),
              accountEmail: Text(""),
            ),
            ListTile(
              title: Text("Profile"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      name: widget.userName,
                      onSave: widget.onNameChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("Settings"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsPage(onThemeChanged: widget.onThemeChanged),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: tasks.isEmpty
          ? Center(child: Text("No Callminders yet"))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (_, i) => taskCard(tasks[i], i),
            ),
    );
  }
}

// ================= PROFILE =================

class ProfilePage extends StatefulWidget {
  final String name;
  final Function(String) onSave;

  ProfilePage({required this.name, required this.onSave});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController controller;
  DateTime? dob;
  File? image;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.name);
  }

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  Future pickDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dob ?? DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: image != null ? FileImage(image!) : null,
                child: image == null ? Icon(Icons.camera_alt, size: 30) : null,
              ),
            ),

            SizedBox(height: 20),

            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            ListTile(
              title: Text(
                dob == null
                    ? "Select Date of Birth"
                    : dob.toString().split(" ")[0],
              ),
              trailing: Icon(Icons.calendar_today),
              onTap: pickDOB,
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                widget.onSave(controller.text);
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
// ================= SETTINGS =================

class SettingsPage extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;

  SettingsPage({required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: Column(
        children: [
          ListTile(
            title: Text("System Theme"),
            onTap: () => onThemeChanged(ThemeMode.system),
          ),
          ListTile(
            title: Text("Light Theme"),
            onTap: () => onThemeChanged(ThemeMode.light),
          ),
          ListTile(
            title: Text("Dark Theme"),
            onTap: () => onThemeChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}
