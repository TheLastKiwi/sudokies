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

/// Run a technique's step on an arbitrary board (used to render an example
/// puzzle in the techniques bank / hint teaching stage).
SolveStep? runStrategyOn(String strategyId, List<int> values) {
  final s = strategyById(strategyId);
  if (s == null) return null;
  final g = CandidateGrid.fromValues(values);
  return s.apply(g);
}
