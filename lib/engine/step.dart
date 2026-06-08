/// Structured output of a solving technique: the move(s) it makes plus an
/// ordered, visual, step-by-step explanation used by the hint UI and the
/// techniques bank screen.
library;

/// Visual role of a highlighted cell or candidate within a hint stage. The UI
/// maps each role to a colour.
enum HighlightRole {
  /// A defining cell/candidate of the pattern (e.g. the pair cells).
  base,

  /// A secondary set of the pattern (e.g. the cover lines of a fish).
  cover,

  /// The hinge/pivot cell of a wing.
  pivot,

  /// A link in a chain.
  link,

  /// A candidate that gets eliminated.
  eliminate,

  /// A cell that gets a value placed.
  place,
}

/// A single placement produced by a technique.
class Placement {
  final int cell;
  final int digit;
  const Placement(this.cell, this.digit);
}

/// A single candidate elimination produced by a technique.
class Elimination {
  final int cell;
  final int digit;
  const Elimination(this.cell, this.digit);

  @override
  bool operator ==(Object other) =>
      other is Elimination && other.cell == cell && other.digit == digit;

  @override
  int get hashCode => Object.hash(cell, digit);
}

/// A candidate (cell + digit) referenced by a hint stage with a visual role.
class CandidateMark {
  final int cell;
  final int digit;
  final HighlightRole role;
  const CandidateMark(this.cell, this.digit, this.role);
}

/// One frame of a technique's visual explanation.
class HintStage {
  final String text;

  /// Cells to highlight, by role.
  final Map<int, HighlightRole> cells;

  /// Specific candidates to highlight, by role.
  final List<CandidateMark> candidates;

  const HintStage({
    required this.text,
    this.cells = const {},
    this.candidates = const [],
  });
}

/// The result of applying a technique once: what it does, and how to show it.
class SolveStep {
  /// Stable identifier of the technique, e.g. `naked_single`.
  final String strategyId;

  /// Human-readable technique name, e.g. `Naked Single`.
  final String strategyName;

  /// Difficulty rank; higher is harder. Buckets map ranks to tiers.
  final int difficultyRank;

  final List<Placement> placements;
  final List<Elimination> eliminations;
  final List<HintStage> stages;

  const SolveStep({
    required this.strategyId,
    required this.strategyName,
    required this.difficultyRank,
    this.placements = const [],
    this.eliminations = const [],
    this.stages = const [],
  });

  bool get isEmpty => placements.isEmpty && eliminations.isEmpty;
}

/// Difficulty tiers, ordered easiest to hardest.
enum Difficulty { easy, medium, hard, expert, extreme }

extension DifficultyLabel on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
      case Difficulty.expert:
        return 'Expert';
      case Difficulty.extreme:
        return 'Extreme';
    }
  }

  String get id => name;
}

Difficulty difficultyFromId(String id) =>
    Difficulty.values.firstWhere((d) => d.name == id, orElse: () => Difficulty.easy);

/// Maps a technique's difficulty rank to a tier. Ranks:
///   0-9 easy, 10-19 medium, 20-29 hard, 30-39 expert, 40+ extreme.
Difficulty tierForRank(int rank) {
  if (rank < 10) return Difficulty.easy;
  if (rank < 20) return Difficulty.medium;
  if (rank < 30) return Difficulty.hard;
  if (rank < 40) return Difficulty.expert;
  return Difficulty.extreme;
}
