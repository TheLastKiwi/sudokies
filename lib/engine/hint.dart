/// Hint engine: finds the next applicable technique on the player's current
/// board. When the player has pencil marks, hints respect them; empty cells
/// the player hasn't annotated fall back to basic (row/col/box) elimination so
/// hints still work when no notes are kept.
library;

import 'grid.dart';
import 'step.dart';
import 'strategies/strategy.dart';

/// The cheapest technique that makes progress on the board defined by [values]
/// (length 81, 0 = empty). When [notes] (player pencil-mark masks) is supplied,
/// the search uses the player's candidates for any cell they've annotated,
/// intersected with the basic set so a stray mark can't introduce a candidate a
/// placed peer already rules out. Returns null if no technique applies.
SolveStep? nextHint(List<int> values, [List<int>? notes]) {
  final g = CandidateGrid.fromValues(values);
  if (notes != null) {
    for (var i = 0; i < cellCount; i++) {
      if (values[i] == 0 && notes[i] != 0) g.cands[i] &= notes[i];
    }
  }
  for (final s in allStrategies) {
    final step = s.apply(g);
    if (step != null && !step.isEmpty) return step;
  }
  return null;
}

/// Render-ready example for a technique: the step plus the candidate masks it
/// fires on. Mined example boards store only placements, but many techniques
/// (hidden subsets, fish, …) only emerge after earlier eliminations. A fresh
/// basic-candidate grid wouldn't reproduce them, so we replay the logical
/// solver cheapest-first until [strategyId] is the chosen technique and return
/// the reduced grid at that moment.
({SolveStep? step, List<int> candidates}) runStrategyExample(
  String strategyId,
  List<int> values,
) {
  final g = CandidateGrid.fromValues(values);
  const maxSteps = 81 * 9 + 81;
  for (var steps = 0; steps < maxSteps && !g.isSolved; steps++) {
    SolveStep? step;
    for (final s in allStrategies) {
      step = s.apply(g);
      if (step != null && !step.isEmpty) break;
      step = null;
    }
    if (step == null) break; // stuck
    if (step.strategyId == strategyId) {
      return (step: step, candidates: List<int>.from(g.cands));
    }
    for (final p in step.placements) {
      if (g.values[p.cell] == 0) g.place(p.cell, p.digit);
    }
    for (final e in step.eliminations) {
      g.eliminate(e.cell, e.digit);
    }
  }
  return (step: null, candidates: List<int>.from(g.cands));
}
