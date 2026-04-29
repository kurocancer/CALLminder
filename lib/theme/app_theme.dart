import 'package:flutter/material.dart';

class AppTheme {
  static const Color deepBlack = Color(0xFF0A0A0A);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonPurple = Color(0xFFB400FF);
  static const Color neonPink = Color(0xFFFF00FF);
  static const Color surfaceDark = Color(0xFF1A1A1A);

  static ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: deepBlack,
    primaryColor: neonBlue,
    colorScheme: ColorScheme.dark(
      primary: neonBlue,
      secondary: neonPurple,
      surface: surfaceDark,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.grey[300],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: neonBlue,
      unselectedItemColor: Colors.grey,
    ),
  );
}
