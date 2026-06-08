import '../grid.dart';
import '../step.dart';

/// Unique Rectangle Type 1: three corners are the same bivalue {a,b} and the
/// fourth corner has {a,b} plus extras. Remove a and b from the fourth.
SolveStep? uniqueRectangleType1(CandidateGrid g) {
  for (var r1 = 0; r1 < 9; r1++) {
    for (var r2 = r1 + 1; r2 < 9; r2++) {
      for (var c1 = 0; c1 < 9; c1++) {
        for (var c2 = c1 + 1; c2 < 9; c2++) {
          final corners = [
            r1 * 9 + c1,
            r1 * 9 + c2,
            r2 * 9 + c1,
            r2 * 9 + c2,
          ];
          // Must occupy exactly two boxes (a valid deadly-pattern rectangle).
          if (corners.map(boxOf).toSet().length != 2) continue;
          if (corners.any((c) => g.values[c] != 0)) continue;

          for (var extra = 0; extra < 4; extra++) {
            final others = [
              for (var k = 0; k < 4; k++) if (k != extra) corners[k]
            ];
            final m = g.cands[others[0]];
            if (popcount(m) != 2) continue;
            if (others.any((c) => g.cands[c] != m)) continue;
            final fourth = corners[extra];
            if ((g.cands[fourth] & m) != m) continue;
            if (popcount(g.cands[fourth]) <= 2) continue;
            final pair = digitsOf(m);
            final elims = [for (final d in pair) Elimination(fourth, d)];
            return SolveStep(
              strategyId: 'unique_rectangle',
              strategyName: 'Unique Rectangle (Type 1)',
              difficultyRank: 40,
              eliminations: elims,
              stages: [
                HintStage(
                  text:
                      'Three corners of this rectangle share {${pair.join(',')}} across two boxes.',
                  cells: {for (final c in others) c: HighlightRole.base},
                  candidates: [
                    for (final c in others)
                      for (final d in pair) CandidateMark(c, d, HighlightRole.base),
                  ],
                ),
                HintStage(
                  text:
                      'If the fourth corner were also just {${pair.join(',')}}, the puzzle would have two solutions — so remove ${pair.join(' and ')} from ${cellName(fourth)}.',
                  cells: {fourth: HighlightRole.eliminate},
                  candidates: [
                    for (final d in pair) CandidateMark(fourth, d, HighlightRole.eliminate),
                  ],
                ),
              ],
            );
          }
        }
      }
    }
  }
  return null;
}
