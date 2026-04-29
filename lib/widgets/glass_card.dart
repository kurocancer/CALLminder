import 'package:flutter/material.dart';

Widget GlassCard({required Widget child, double? height}) {
  return Container(
    width: double.infinity,
    height: height ?? 120,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Color(0xFF1A1A1A).withOpacity(0.7),
      border: Border.all(
        color: AppTheme.neonBlue.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppTheme.neonBlue.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    ),
    child: child,
  );
}
