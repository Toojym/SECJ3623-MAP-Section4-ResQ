import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF3B6DD4);
  static const Color primaryDark = Color(0xFF2A56B5);
  static const Color primaryLight = Color(0xFFEEF2FD);

  // Semantic
  static const Color danger = Color(0xFFE53935);
  static const Color dangerLight = Color(0xFFFFEBEB);
  static const Color safe = Color(0xFF43A047);
  static const Color safeLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFB8C00);
  static const Color warningLight = Color(0xFFFFF3E0);

  // Neutrals
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFB0B7C3);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // Role accent colours
  static const Color citizenAccent = Color(0xFF3B6DD4);
  static const Color volunteerAccent = Color(0xFF8B5CF6);
  static const Color officerAccent = Color(0xFF0891B2);

  // Gradient stops
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B6DD4), Color(0xFF5B8DEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF3B6DD4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
