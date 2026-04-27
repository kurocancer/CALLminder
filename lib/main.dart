import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_screen.dart';
import 'notification_service.dart';

// ================= MAIN =================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
    await WakelockPlus.enable();
  } catch (e) {
    print("Init error: $e");
  }
  runApp(RemindCallApp());
}

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'call_channel',
    'Call Channel',
    description: 'Incoming call style notifications',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await initializeBackgroundService();
  runApp(RemindCallApp());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'call_channel',
      initialNotificationTitle: 'Callminder Shield Active',
      initialNotificationContent:
          'Running in the background. Ready to wake up.',
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
  // Background processes run here
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
  bool isDarkMode = false;
  String? userName;
  DateTime? userDOB;
  String? profileImagePath;

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
    String? dobStr = prefs.getString("dob");
    if (dobStr != null) {
      try {
        userDOB = DateTime.parse(dobStr);
      } catch (e) {
        print("Error parsing DOB: $e");
      }
    }
    profileImagePath = prefs.getString("profile_image");
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
              profileImagePath: profileImagePath,
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
  String repeatMode;
  List<int> customDays;
  int? notificationId;
  String? details;

  CallTask(
    this.task,
    this.dateTime,
    this.snooze,
    this.repeatMode,
    this.customDays, {
    this.notificationId,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    "task": task,
    "dateTime": dateTime.toIso8601String(),
    "snooze": snooze,
    "repeatMode": repeatMode,
    "customDays": customDays,
    "notificationId": notificationId,
    "details": details,
  };

  factory CallTask.fromJson(Map<String, dynamic> json) {
    return CallTask(
      json["task"],
      DateTime.parse(json["dateTime"]),
      json["snooze"] ?? 0,
      json["repeatMode"] ?? 'none',
      List<int>.from(json["customDays"] ?? []),
      notificationId: json["notificationId"],
      details: json["details"],
    );
  }

  DateTime calculateNextTime() {
    DateTime now = DateTime.now();
    DateTime next = dateTime;

    if (repeatMode == 'daily') {
      next = next.add(Duration(days: 1));
      while (next.isBefore(now)) next = next.add(Duration(days: 1));
    } else if (repeatMode == 'weekly') {
      next = next.add(Duration(days: 7));
      while (next.isBefore(now)) next = next.add(Duration(days: 7));
    } else if (repeatMode == 'custom' && customDays.isNotEmpty) {
      next = next.add(Duration(days: 1));
      while (next.isBefore(now) || !customDays.contains(next.weekday)) {
        next = next.add(Duration(days: 1));
      }
    }
    return next;
  }
}

// ================= HOME =================

class HomeScreen extends StatefulWidget {
  final String userName;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Function(String) onNameChanged;
  final String? profileImagePath;

  HomeScreen({
    required this.userName,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onNameChanged,
    this.profileImagePath,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CallTask> tasks = [];
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    loadTasks();
    checkInitialLaunch();
    _requestPermissions();

    _notificationSubscription =
        NotificationService.selectNotificationStream.stream.listen(
      (NotificationResponse? response) {
        if (response != null && response.payload != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CallScreen(payload: response.payload!)),
          ).then((_) => loadTasks());
        }
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
    });
  }

  void _requestPermissions() async {
    // Request microphone permission
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (micStatus.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone permission denied. Please enable in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    // Request notification permission
    await Permission.notification.request();
  }

  void checkInitialLaunch() async {
    NotificationResponse? response = await NotificationService.checkInitialLaunch();
    if (response != null && response.payload != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CallScreen(payload: response.payload!)),
      ).then((_) => loadTasks());
    }
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
    TextEditingController detailsController = TextEditingController(
      text: existing?.details ?? "",
    );

    DateTime? date = existing?.dateTime;
    TimeOfDay? time = existing != null
        ? TimeOfDay.fromDateTime(existing.dateTime)
        : null;

    String repeatMode = existing?.repeatMode ?? 'none';
    List<int> customDays = List.from(existing?.customDays ?? []);

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

                  SizedBox(height: 10),

                  TextField(
                    controller: detailsController,
                    decoration: InputDecoration(
                      labelText: "Details (optional)",
                      hintText: "Add any notes or details for the AI...",
                    ),
                    maxLines: 3,
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

                  ListTile(
                    title: Text("Repeat"),
                    trailing: DropdownButton<String>(
                      value: repeatMode,
                      items: [
                        DropdownMenuItem(value: 'none', child: Text("Never")),
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text("Every Day"),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text("Every Week"),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text("Custom Days"),
                        ),
                      ],
                      onChanged: (v) => setStateSheet(() => repeatMode = v!),
                    ),
                  ),

                  if (repeatMode == 'custom')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Wrap(
                        spacing: 8,
                        children: List.generate(7, (index) {
                          int day = index + 1; // 1 = Monday, 7 = Sunday
                          List<String> dayNames = [
                            "M",
                            "T",
                            "W",
                            "T",
                            "F",
                            "S",
                            "S",
                          ];
                          bool isSelected = customDays.contains(day);
                          return FilterChip(
                            label: Text(dayNames[index]),
                            selected: isSelected,
                            onSelected: (selected) {
                              setStateSheet(() {
                                if (selected) {
                                  customDays.add(day);
                                } else {
                                  customDays.remove(day);
                                }
                              });
                            },
                          );
                        }),
                      ),
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

                      final newTask = CallTask(
                        controller.text,
                        dt,
                        0,
                        repeatMode,
                        customDays,
                        details: detailsController.text.isNotEmpty
                            ? detailsController.text
                            : null,
                      );

                      setState(() {
                        if (existing == null) {
                          tasks.add(newTask);
                        } else {
                          tasks[index!] = newTask;
                        }
                      });

                      saveTasks();

                      int notificationId =
                        DateTime.now().millisecondsSinceEpoch.remainder(
                          100000,
                        );

                    // Store notification ID in the task
                    newTask.notificationId = notificationId;

                    NotificationService.scheduleCall(
                      id: notificationId,
                      title: "Callminder",
                      body: newTask.task,
                      scheduledTime: newTask.dateTime,
                      payload: jsonEncode(newTask.toJson()),
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
    String subtitle =
        "${t.dateTime.toString().split(" ")[0]} • ${TimeOfDay.fromDateTime(t.dateTime).format(context)}";
    if (t.repeatMode == 'daily') subtitle += " 🔄 Daily";
    if (t.repeatMode == 'weekly') subtitle += " 🔄 Weekly";
    if (t.repeatMode == 'custom') subtitle += " 🔄 Custom";

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Text(t.task, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
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
                backgroundImage: widget.profileImagePath != null
                    ? FileImage(File(widget.profileImagePath!))
                    : null,
                child: widget.profileImagePath == null
                    ? Icon(Icons.person)
                    : null,
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
                ).then((_) => loadTasks());
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
    loadProfileData();
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

    widget.onSave(controller.text);

    if (dob != null) {
      await prefs.setString("dob", dob!.toIso8601String());
    }

    if (image != null) {
      // Copy image to app documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = image!.path.split('/').last;
      final savedImage = await image!.copy('${appDir.path}/$fileName');
      await prefs.setString("profile_image", savedImage.path);
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

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  SettingsPage({required this.isDarkMode, required this.onThemeChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int defaultSnooze = 10;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    loadSettings();
    _loadApiKey();
  }

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      defaultSnooze = prefs.getInt("default_snooze") ?? 10;
    });
  }

  void _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString("gemini_api_key");
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey = "AIzaSyAB-ys0uexYtCcv514XKihkBCWizxwbjp4";
        prefs.setString("gemini_api_key", _apiKey!);
      }
    });
  }

  void _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("gemini_api_key", key);
    setState(() => _apiKey = key);
  }

  void _editApiKey() {
    TextEditingController controller = TextEditingController(
      text: _apiKey ?? "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Gemini API Key"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter API key",
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _saveApiKey(controller.text);
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _editSnoozeDuration() {
    TextEditingController customController = TextEditingController(
      text: defaultSnooze.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Custom Snooze"),
          content: TextField(
            controller: customController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Minutes",
              hintText: "Enter exact minutes (e.g., 2, 45)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                int? newValue = int.tryParse(customController.text);
                if (newValue != null && newValue > 0) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt("default_snooze", newValue);
                  setState(() {
                    defaultSnooze = newValue;
                  });
                }
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text("Dark Mode"),
            subtitle: Text("Toggle dark theme on or off"),
            value: widget.isDarkMode,
            onChanged: (bool value) {
              widget.onThemeChanged(value);
            },
          ),
          Divider(),
          ListTile(
            title: Text("Default Snooze Duration"),
            subtitle: Text("$defaultSnooze minutes added when snoozing"),
            trailing: Icon(Icons.edit, color: Colors.blueAccent),
            onTap: _editSnoozeDuration,
          ),
          Divider(),
          ListTile(
            title: Text("Gemini API Key"),
            subtitle: Text(
              _apiKey == null || _apiKey!.isEmpty
                  ? "Not set"
                  : "••••••${_apiKey!.substring(_apiKey!.length - 4)}",
            ),
            trailing: Icon(Icons.edit, color: Colors.green),
            onTap: _editApiKey,
          ),
        ],
      ),
    );
  }
}
