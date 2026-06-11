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

/// Board palette, with a variant per brightness. Resolve the active one with
/// [BoardColors.of].
class BoardColors {
  final Color cell;
  final Color given;
  final Color entry;
  final Color wrong;
  final Color selected;
  final Color peer;
  final Color sameDigit;
  final Color sameDigitNote;
  final Color gridLine;
  final Color gridLineThick;
  final Color pencil;
  final Color pencilHighlight;

  const BoardColors({
    required this.cell,
    required this.given,
    required this.entry,
    required this.wrong,
    required this.selected,
    required this.peer,
    required this.sameDigit,
    required this.sameDigitNote,
    required this.gridLine,
    required this.gridLineThick,
    required this.pencil,
    required this.pencilHighlight,
  });

  static const light = BoardColors(
    cell: Colors.white,
    given: Color(0xFF1A1A1A),
    entry: Color(0xFF1565C0),
    wrong: Color(0xFFD32F2F),
    selected: Color(0xFFBBDEFB),
    peer: Color(0xFFE8F0FE),
    sameDigit: Color(0xFFC5E1A5),
    sameDigitNote: Color(0xFFECF5DF),
    gridLine: Color(0xFF90A4AE),
    gridLineThick: Color(0xFF37474F),
    pencil: Color(0xFF607D8B),
    pencilHighlight: Colors.black,
  );

  static const dark = BoardColors(
    cell: Color(0xFF1E1E1E),
    given: Color(0xFFECEFF1),
    entry: Color(0xFF90CAF9),
    wrong: Color(0xFFEF9A9A),
    selected: Color(0xFF1E4976),
    peer: Color(0xFF263238),
    sameDigit: Color(0xFF33691E),
    sameDigitNote: Color(0xFF253420),
    gridLine: Color(0xFF546E7A),
    gridLineThick: Color(0xFFB0BEC5),
    pencil: Color(0xFF90A4AE),
    pencilHighlight: Colors.white,
  );

  static BoardColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme() {
  return ThemeData(
    colorSchemeSeed: const Color(0xFF1565C0),
    useMaterial3: true,
    brightness: Brightness.light,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    colorSchemeSeed: const Color(0xFF1565C0),
    useMaterial3: true,
    brightness: Brightness.dark,
  );
}
