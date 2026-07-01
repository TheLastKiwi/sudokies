/// Greater-than technique: for each `lo < hi` relation, the smaller cell can't
/// hold a digit at or above the larger cell's maximum, and the larger cell can't
/// hold a digit at or below the smaller cell's minimum. Applied repeatedly the
/// solver chains these along a run of inequalities. Short-circuits on
/// constraint-free grids.
library;

import '../constraints/inequality.dart';
import '../grid.dart';
import '../step.dart';

SolveStep? inequality(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final ineq in g.constraints.whereType<Inequality>()) {
    final minLo = _minOf(g, ineq.lo);
    final maxHi = _maxOf(g, ineq.hi);
    if (minLo == 0 || maxHi == 0) continue; // a dead cell — skip

    final elims = <Elimination>[];
    // lo < hi, and hi is at most maxHi, so lo <= maxHi - 1.
    if (g.values[ineq.lo] == 0) {
      for (final d in digitsOf(g.cands[ineq.lo])) {
        if (d >= maxHi) elims.add(Elimination(ineq.lo, d));
      }
    }
    // hi > lo, and lo is at least minLo, so hi >= minLo + 1.
    if (g.values[ineq.hi] == 0) {
      for (final d in digitsOf(g.cands[ineq.hi])) {
        if (d <= minLo) elims.add(Elimination(ineq.hi, d));
      }
    }
    if (elims.isEmpty) continue;
    return SolveStep(
      strategyId: 'inequality',
      strategyName: 'Inequality',
      difficultyRank: 7,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'One cell must be less than the other across this marker.',
          cells: {ineq.lo: HighlightRole.base, ineq.hi: HighlightRole.base},
        ),
        HintStage(
          text: 'Remove digits that can\'t honour the inequality.',
          candidates: [
            for (final e in elims)
              CandidateMark(e.cell, e.digit, HighlightRole.eliminate),
          ],
        ),
      ],
    );
  }
  return null;
}

int _minOf(CandidateGrid g, int c) {
  if (g.values[c] != 0) return g.values[c];
  final d = digitsOf(g.cands[c]);
  return d.isEmpty ? 0 : d.first;
}

int _maxOf(CandidateGrid g, int c) {
  if (g.values[c] != 0) return g.values[c];
  final d = digitsOf(g.cands[c]);
  return d.isEmpty ? 0 : d.last;
}
