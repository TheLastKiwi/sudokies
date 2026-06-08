import 'package:flutter/material.dart';

import '../engine/step.dart';

/// Colour for a hint highlight role.
Color roleColor(HighlightRole role) {
  switch (role) {
    case HighlightRole.base:
      return const Color(0xFF4FC3F7); // light blue
    case HighlightRole.cover:
      return const Color(0xFFFFB74D); // orange
    case HighlightRole.pivot:
      return const Color(0xFFBA68C8); // purple
    case HighlightRole.link:
      return const Color(0xFF81C784); // green
    case HighlightRole.eliminate:
      return const Color(0xFFE57373); // red
    case HighlightRole.place:
      return const Color(0xFF66BB6A); // strong green
  }
}

class BoardColors {
  static const given = Color(0xFF1A1A1A);
  static const entry = Color(0xFF1565C0);
  static const wrong = Color(0xFFD32F2F);
  static const selected = Color(0xFFBBDEFB);
  static const peer = Color(0xFFE8F0FE);
  static const sameDigit = Color(0xFFC5E1A5);
  static const gridLine = Color(0xFF90A4AE);
  static const gridLineThick = Color(0xFF37474F);
  static const pencil = Color(0xFF607D8B);
}

ThemeData buildTheme() {
  return ThemeData(
    colorSchemeSeed: const Color(0xFF1565C0),
    useMaterial3: true,
    brightness: Brightness.light,
  );
}
