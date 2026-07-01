/// Kropki / ratio / sum dot technique: keep only the digits in each dotted cell
/// that have a partner in the adjacent cell satisfying the relation. Short-
/// circuits on constraint-free grids.
library;

import '../constraints/pair_dot.dart';
import '../grid.dart';
import '../step.dart';

SolveStep? pairDot(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final dot in g.constraints.whereType<PairDot>()) {
    final elims = <Elimination>[];
    _prune(g, dot, dot.a, dot.b, elims);
    _prune(g, dot, dot.b, dot.a, elims);
    if (elims.isEmpty) continue;
    return SolveStep(
      strategyId: 'pair_dot',
      strategyName: 'Dot Constraint',
      difficultyRank: 8,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'The two cells joined by this marker must satisfy its '
              'relation.',
          cells: {dot.a: HighlightRole.base, dot.b: HighlightRole.base},
        ),
        HintStage(
          text: 'Remove digits with no valid partner in the other cell.',
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

void _prune(
    CandidateGrid g, PairDot dot, int x, int y, List<Elimination> elims) {
  if (g.values[x] != 0) return;
  final yVals =
      g.values[y] != 0 ? [g.values[y]] : digitsOf(g.cands[y]);
  for (final d in digitsOf(g.cands[x])) {
    if (!yVals.any((e) => dot.satisfies(d, e))) elims.add(Elimination(x, d));
  }
}
