/// Hint engine: finds the next applicable technique on the player's current
/// board, using only the pencil marks the player has actually entered. A cell
/// the player hasn't annotated contributes no candidates, so a technique only
/// surfaces once enough notes are present for it to be visible to the player.
library;

import 'constraints/constraint.dart';
import 'grid.dart';
import 'step.dart';
import 'strategies/strategy.dart';

/// The cheapest technique that makes progress on the board defined by [values]
/// (length 81, 0 = empty). When [notes] (player pencil-mark masks) is supplied,
/// the search restricts every empty cell to the player's own candidates,
/// intersected with the basic set so a stray mark can't introduce a candidate a
/// placed peer already rules out. Empty cells the player hasn't annotated have
/// no candidates, so no technique applies until they add notes. Returns null if
/// no technique applies.
SolveStep? nextHint(
  List<int> values, [
  List<int>? notes,
  List<Constraint> constraints = const [],
]) {
  final g = CandidateGrid.fromValues(values, constraints: constraints);
  if (notes != null) {
    for (var i = 0; i < cellCount; i++) {
      if (values[i] == 0) g.cands[i] &= notes[i];
    }
  }
  for (final s in allStrategies) {
    final step = s.apply(g);
    if (step != null && !step.isEmpty) return step;
  }
  return null;
}

/// Teaching fallback for when the player's notes only expose a technique
/// harder than the puzzle's rating — usually a sign that stale pencil marks
/// are hiding the intended line. Replays the logical solver cheapest-first
/// from the basic candidates of [values] and returns the first step of tier at
/// most [maxTier] whose eliminations remove at least one of the player's
/// [notes]: a strategy the player can apply right now to clean up existing
/// notes. Returns null if the replay gets stuck or solves the board without
/// ever eliminating one of the player's notes within the tier cap.
SolveStep? noteRemovalHint(
  List<int> values,
  List<int> notes,
  Difficulty maxTier, [
  List<Constraint> constraints = const [],
]) {
  final g = CandidateGrid.fromValues(values, constraints: constraints);
  const maxSteps = 81 * 9 + 81;
  for (var steps = 0; steps < maxSteps && !g.isSolved; steps++) {
    SolveStep? step;
    for (final s in allStrategies) {
      step = s.apply(g);
      if (step != null && !step.isEmpty) break;
      step = null;
    }
    if (step == null) return null;
    if (tierForRank(step.difficultyRank).index <= maxTier.index &&
        step.eliminations.any((e) => maskHas(notes[e.cell], e.digit))) {
      return step;
    }
    for (final p in step.placements) {
      if (g.values[p.cell] == 0) g.place(p.cell, p.digit);
    }
    for (final e in step.eliminations) {
      g.eliminate(e.cell, e.digit);
    }
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
  List<int> values, [
  List<Constraint> constraints = const [],
]) {
  final g = CandidateGrid.fromValues(values, constraints: constraints);
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
