import 'package:flutter/material.dart';

abstract final class VisualScanStyle {
  static const background = Color(0xFF121211);
  static const surface = Color(0xFF1C1C1A);
  static const navigation = Color(0xFF171715);
  static const border = Color(0xFF2D2C28);
  static const text = Color(0xFFF7F2E9);
  static const muted = Color(0xFFB5AEA2);
  static const amber = Color(0xFFD49A45);

  static TextStyle heading(double size) => TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    height: 1.15,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w700,
    color: text,
  );
}
