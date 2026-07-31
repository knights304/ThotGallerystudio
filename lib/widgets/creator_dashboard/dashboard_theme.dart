import 'package:flutter/material.dart';

class CreatorDashboardTheme {
  const CreatorDashboardTheme._();

  static const Color purple = Color(0xFF9B5CFF);
  static const Color deepPurple = Color(0xFF5D2A86);
  static const Color silver = Color(0xFFD7D3DF);
  static const Color panel = Color(0xFF17121F);
  static const Color panelRaised = Color(0xFF21182C);
  static const Color success = Color(0xFF54D69A);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF6B81);

  static Color progressColor(double progress) {
    if (progress >= 0.9) return danger;
    if (progress >= 0.7) return warning;
    return success;
  }
}
