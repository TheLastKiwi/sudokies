import 'dart:convert';

import '../engine/step.dart';
import 'variant_spec.dart';

/// An immutable puzzle: its share code, the givens, the full solution, its
/// graded difficulty tier, and — for variant sudoku — an optional [variant]
/// carrying the extra rules. A classic puzzle has `variant == null`.
class Puzzle {
  final String code;
  final String board; // 81 chars, '.' for blanks
  final String solution; // 81 digits
  final Difficulty difficulty;
  final VariantSpec? variant;

  const Puzzle({
    required this.code,
    required this.board,
    required this.solution,
    required this.difficulty,
    this.variant,
  });

  bool get isVariant => variant != null;

  factory Puzzle.fromJson(Map<String, dynamic> json) => Puzzle(
        code: (json['code'] as String).toUpperCase(),
        board: json['board'] as String,
        solution: json['solution'] as String,
        difficulty: difficultyFromId(json['difficulty'] as String),
        variant: json['variant'] == null
            ? null
            : VariantSpec.fromJson(
                Map<String, dynamic>.from(json['variant'] as Map)),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'board': board,
        'solution': solution,
        'difficulty': difficulty.id,
        if (variant != null) 'variant': variant!.toJson(),
      };

  List<int> get givenValues =>
      [for (final ch in board.split('')) ch == '.' || ch == '0' ? 0 : int.parse(ch)];

  List<int> get solutionValues => [for (final ch in solution.split('')) int.parse(ch)];

  /// A self-contained, copy-pasteable share string. Variant puzzles can't live
  /// in the code-based puzzle bank (they carry arbitrary rules), so the whole
  /// puzzle is packed into a versioned base64url payload that [decode] reverses.
  String encode() {
    final payload = base64Url.encode(utf8.encode(jsonEncode(toJson())));
    return 'SUDOKIES1:$payload';
  }

  /// Rebuild a puzzle from an [encode]d share string. The `SUDOKIES1:` prefix
  /// is optional so a bare payload still decodes.
  static Puzzle decode(String s) {
    var payload = s.trim();
    const prefix = 'SUDOKIES1:';
    if (payload.startsWith(prefix)) payload = payload.substring(prefix.length);
    final jsonStr = utf8.decode(base64Url.decode(payload));
    return Puzzle.fromJson(Map<String, dynamic>.from(jsonDecode(jsonStr) as Map));
  }
}
