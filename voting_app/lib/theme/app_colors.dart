import 'package:flutter/material.dart';

/// Premium voting app palette (dark SaaS).
abstract final class AppColors {
  static const Color bgPrimary = Color(0xFF0A0E21);
  static const Color bgSecondary = Color(0xFF1A1F38);
  static const Color accentPrimary = Color(0xFF6C63FF);
  static const Color accentSecondary = Color(0xFF00D4FF);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF5252);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6C63FF),
      Color(0xFF00D4FF),
      Color(0xFF1A1F38),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF12162C),
      Color(0xFF0A0E21),
    ],
  );

  static const LinearGradient cardGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x336C63FF),
      Color(0x2200D4FF),
    ],
  );
}
