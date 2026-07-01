/// Logical (human-style) solver used to grade puzzles by the hardest technique
/// required. Applies techniques cheapest-first, restarting after each move.
library;

import 'constraints/constraint.dart';
import 'grid.dart';
import 'step.dart';
import 'strategies/strategy.dart';

class SolveResult {
  final bool solved;
  final int hardestRank;
  final Difficulty? tier;
  final Map<String, int> usage; // strategyId -> times applied
  final int steps;

  /// The board string after solving stopped — a full 81-digit solution when
  /// [solved], otherwise the partial grid (used by the editor to store the
  /// derived solution of an authored puzzle).
  final String board;

  const SolveResult({
    required this.solved,
    required this.hardestRank,
    required this.tier,
    required this.usage,
    required this.steps,
    required this.board,
  });
}

/// Attempt to solve [puzzle] using only the registered logical techniques.
///
/// [onStep] is invoked before each technique is applied, with the technique id
/// and the board string at that moment — used by the offline tool to mine a
/// clean example position for every technique.
SolveResult solveLogically(
  String puzzle, {
  void Function(String strategyId, String boardBefore)? onStep,
  List<Constraint> constraints = const [],
}) {
  final g = CandidateGrid.fromString(puzzle, constraints: constraints);
  var hardest = -1;
  var steps = 0;
  final usage = <String, int>{};
  // Generous safety bound: each step removes at least one candidate/placement.
  const maxSteps = 81 * 9 + 81;
  while (!g.isSolved && steps < maxSteps) {
    SolveStep? step;
    for (final s in allStrategies) {
      step = s.apply(g);
      if (step != null) break;
    }
    if (step == null) break; // stuck — needs a technique we don't implement
    onStep?.call(step.strategyId, g.toBoardString());
    var changed = false;
    for (final p in step.placements) {
      if (g.values[p.cell] == 0) {
        g.place(p.cell, p.digit);
        changed = true;
      }
    }
    for (final e in step.eliminations) {
      if (g.eliminate(e.cell, e.digit)) changed = true;
    }
    if (!changed) break; // defensive: avoid spinning on a no-op step
    if (step.difficultyRank > hardest) hardest = step.difficultyRank;
    usage[step.strategyId] = (usage[step.strategyId] ?? 0) + 1;
    steps++;
  }
  final solved = g.isSolved;
  return SolveResult(
    solved: solved,
    hardestRank: hardest,
    tier: solved ? tierForRank(hardest) : null,
    usage: usage,
    steps: steps,
    board: g.toBoardString(),
  );
}
