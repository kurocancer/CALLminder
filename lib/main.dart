import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'call_screen.dart';
import 'notification_service.dart';

// ================= MAIN =================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await initializeBackgroundService(); // Phase 1: Background Service Init
  runApp(RemindCallApp());
}

// Phase 1: Basic Background Service Setup
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'call_channel',
      initialNotificationTitle: 'Callminder is active',
      initialNotificationContent:
          'Running in background to ensure you never miss a task.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Background logic goes here
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

class RemindCallApp extends StatefulWidget {
  @override
  _RemindCallAppState createState() => _RemindCallAppState();
}

class _RemindCallAppState extends State<RemindCallApp> {
  bool isDarkMode = false; // Phase 2: Simplified to Light/Dark
  String? userName;

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  void loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("username");
      isDarkMode = prefs.getBool("isDarkMode") ?? false;
    });
  }

  void setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("username", name);
    setState(() => userName = name);
  }

  void toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDarkMode", isDark);
    setState(() => isDarkMode = isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: userName == null
          ? CreateProfileScreen(onSave: setUserName)
          : HomeScreen(
              userName: userName!,
              isDarkMode: isDarkMode,
              onThemeChanged: toggleTheme,
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
              TextField(
                controller: controller,
                decoration: InputDecoration(hintText: "Enter your name"),
              ),
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
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Function(String) onNameChanged;

  HomeScreen({
    required this.userName,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onNameChanged,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CallTask> tasks = [];
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    loadTasks();
    loadProfileImage();
  }

  void loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profileImagePath = prefs.getString("profile_image");
    });
  }

  void triggerCall(CallTask task) {
    final diff = task.dateTime.difference(DateTime.now());

    if (diff.isNegative) return;

    Future.delayed(diff, () {
      if (!mounted) return;

      setState(() {
        tasks.removeWhere(
          (t) => t.task == task.task && t.dateTime == task.dateTime,
        );
      });

      saveTasks();

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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: "Task Name"),
                  ),

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

                  SizedBox(height: 10),

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
                    child: Text("Save Task"),
                  ),
                  SizedBox(height: 20),
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
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Text(t.task, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${t.dateTime.toString().split(" ")[0]} • ${TimeOfDay.fromDateTime(t.dateTime).format(context)}",
        ),
        leading: IconButton(
          icon: Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => deleteTask(i),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: Colors.blueAccent),
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
              accountEmail: Text("Stay on track!"),
              currentAccountPicture: CircleAvatar(
                backgroundImage: profileImagePath != null
                    ? FileImage(File(profileImagePath!))
                    : null,
                child: profileImagePath == null ? Icon(Icons.person) : null,
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      name: widget.userName,
                      onSave: (newName) {
                        widget.onNameChanged(newName);
                        loadProfileImage(); // Reload image after returning
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      isDarkMode: widget.isDarkMode,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: tasks.isEmpty
          ? Center(child: Text("No Callminders yet! Add one below."))
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
    loadProfileData(); // Phase 3: Load on init
  }

  void loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? savedDOB = prefs.getString("dob");
      if (savedDOB != null) dob = DateTime.parse(savedDOB);

      String? savedImagePath = prefs.getString("profile_image");
      if (savedImagePath != null) image = File(savedImagePath);
    });
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

  void saveProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // Save Name
    widget.onSave(controller.text);

    // Phase 3: Save DOB
    if (dob != null) {
      await prefs.setString("dob", dob!.toIso8601String());
    }

    // Phase 3: Save Photo Path
    // (Note: For long term persistence, copy picked.path to getApplicationDocumentsDirectory)
    if (image != null) {
      await prefs.setString("profile_image", image!.path);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: image != null ? FileImage(image!) : null,
                child: image == null ? Icon(Icons.camera_alt, size: 40) : null,
              ),
            ),
            SizedBox(height: 30),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              title: Text(
                dob == null
                    ? "Select Date of Birth"
                    : "DOB: ${dob.toString().split(" ")[0]}",
              ),
              trailing: Icon(Icons.calendar_today),
              onTap: pickDOB,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: saveProfile,
              child: Text("Save Profile", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= SETTINGS =================

class SettingsPage extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  SettingsPage({required this.isDarkMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
          // Phase 2: Theme Switch
          SwitchListTile(
            title: Text("Dark Mode"),
            subtitle: Text("Toggle dark theme on or off"),
            value: isDarkMode,
            onChanged: (bool value) {
              onThemeChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
