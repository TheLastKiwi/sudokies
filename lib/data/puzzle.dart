import '../engine/step.dart';

/// An immutable puzzle: its share code, the givens, the full solution, and its
/// graded difficulty tier.
class Puzzle {
  final String code;
  final String board; // 81 chars, '.' for blanks
  final String solution; // 81 digits
  final Difficulty difficulty;

  const Puzzle({
    required this.code,
    required this.board,
    required this.solution,
    required this.difficulty,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) => Puzzle(
        code: (json['code'] as String).toUpperCase(),
        board: json['board'] as String,
        solution: json['solution'] as String,
        difficulty: difficultyFromId(json['difficulty'] as String),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'board': board,
        'solution': solution,
        'difficulty': difficulty.id,
      };

  List<int> get givenValues =>
      [for (final ch in board.split('')) ch == '.' || ch == '0' ? 0 : int.parse(ch)];

  List<int> get solutionValues => [for (final ch in solution.split('')) int.parse(ch)];
}
