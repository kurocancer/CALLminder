import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/sign_in_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/ai_creator.dart';
import 'screens/squad_screen.dart';
import 'notification_service.dart';
import 'call_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
    print("Firebase app name: ${Firebase.app().name}");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Initialize notifications
  try {
    await NotificationService.init();
    await WakelockPlus.enable();
    print("Notifications initialized");
  } catch (e) {
    print("Init error: $e");
  }

  runApp(CallminderApp());
}

class CallminderApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  CallminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppTheme.deepBlack,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.neonBlue),
              ),
            );
          }

          if (snapshot.hasData) {
            return MainScreen();
          }

          return SignInScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeDashboard(),
    AICreator(),
    SquadScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppTheme.surfaceDark,
        selectedItemColor: AppTheme.neonBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Squad',
          ),
        ],
      ),
    );
  }
}
