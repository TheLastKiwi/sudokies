import '../grid.dart';
import '../step.dart';

bool _sees(int a, int b) => peers[a].contains(b);

SolveStep? xyWing(CandidateGrid g) {
  final bivalue = [
    for (var i = 0; i < cellCount; i++)
      if (g.values[i] == 0 && popcount(g.cands[i]) == 2) i
  ];
  for (final pivot in bivalue) {
    final pd = digitsOf(g.cands[pivot]); // [x, y]
    final x = pd[0], y = pd[1];
    final wings = [for (final c in bivalue) if (c != pivot && _sees(pivot, c)) c];
    for (final w1 in wings) {
      for (final w2 in wings) {
        if (w2 <= w1) continue;
        final d1 = g.cands[w1], d2 = g.cands[w2];
        // w1 must be {x, z}, w2 must be {y, z} (or swapped), z not in pivot.
        for (final assign in [
          [x, y],
          [y, x],
        ]) {
          final px = assign[0], py = assign[1];
          if (!maskHas(d1, px) || !maskHas(d2, py)) continue;
          final z1 = digitsOf(d1 & ~maskOf(px));
          final z2 = digitsOf(d2 & ~maskOf(py));
          if (z1.length != 1 || z2.length != 1) continue;
          final z = z1.first;
          if (z != z2.first) continue;
          if (z == x || z == y) continue;
          // Eliminate z from cells seeing both wings.
          final elims = <Elimination>[];
          for (var c = 0; c < cellCount; c++) {
            if (c == pivot || c == w1 || c == w2) continue;
            if (g.values[c] != 0 || !maskHas(g.cands[c], z)) continue;
            if (_sees(c, w1) && _sees(c, w2)) elims.add(Elimination(c, z));
          }
          if (elims.isEmpty) continue;
          return SolveStep(
            strategyId: 'xy_wing',
            strategyName: 'XY-Wing',
            difficultyRank: 32,
            eliminations: elims,
            stages: [
              HintStage(
                text:
                    'Pivot ${cellName(pivot)} holds {$px,$py}; wings ${cellName(w1)} and ${cellName(w2)} each share one of those plus $z.',
                cells: {
                  pivot: HighlightRole.pivot,
                  w1: HighlightRole.base,
                  w2: HighlightRole.base,
                },
                candidates: [
                  for (final d in pd) CandidateMark(pivot, d, HighlightRole.pivot),
                  for (final d in digitsOf(d1)) CandidateMark(w1, d, HighlightRole.base),
                  for (final d in digitsOf(d2)) CandidateMark(w2, d, HighlightRole.base),
                ],
              ),
              HintStage(
                text:
                    'Whichever way the pivot resolves, one wing becomes $z — so $z is removed from cells seeing both wings.',
                cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
                candidates: [
                  for (final e in elims) CandidateMark(e.cell, z, HighlightRole.eliminate),
                ],
              ),
            ],
          );
        }
      }
    }
  }
  return null;
}

SolveStep? xyzWing(CandidateGrid g) {
  for (var pivot = 0; pivot < cellCount; pivot++) {
    if (g.values[pivot] != 0 || popcount(g.cands[pivot]) != 3) continue;
    final pd = digitsOf(g.cands[pivot]);
    final wings = [
      for (final c in peers[pivot])
        if (g.values[c] == 0 &&
            popcount(g.cands[c]) == 2 &&
            (g.cands[c] & ~g.cands[pivot]) == 0)
          c
    ];
    for (var i = 0; i < wings.length; i++) {
      for (var j = i + 1; j < wings.length; j++) {
        final w1 = wings[i], w2 = wings[j];
        // The shared digit z is in pivot, w1 and w2.
        final common = g.cands[pivot] & g.cands[w1] & g.cands[w2];
        if (popcount(common) != 1) continue;
        // The two wings together with the pivot must cover all three digits.
        if ((g.cands[w1] | g.cands[w2]) != g.cands[pivot]) continue;
        final z = singleDigit(common);
        final elims = <Elimination>[];
        for (final c in peers[pivot]) {
          if (c == w1 || c == w2) continue;
          if (g.values[c] != 0 || !maskHas(g.cands[c], z)) continue;
          if (_sees(c, w1) && _sees(c, w2)) elims.add(Elimination(c, z));
        }
        if (elims.isEmpty) continue;
        return SolveStep(
          strategyId: 'xyz_wing',
          strategyName: 'XYZ-Wing',
          difficultyRank: 41,
          eliminations: elims,
          stages: [
            HintStage(
              text:
                  'Pivot ${cellName(pivot)} holds {${pd.join(',')}}; wings ${cellName(w1)} and ${cellName(w2)} share digit $z with it.',
              cells: {
                pivot: HighlightRole.pivot,
                w1: HighlightRole.base,
                w2: HighlightRole.base,
              },
              candidates: [
                for (final d in pd) CandidateMark(pivot, d, HighlightRole.pivot),
                for (final d in digitsOf(g.cands[w1])) CandidateMark(w1, d, HighlightRole.base),
                for (final d in digitsOf(g.cands[w2])) CandidateMark(w2, d, HighlightRole.base),
              ],
            ),
            HintStage(
              text:
                  'One of the three must be $z, so remove $z from any cell seeing all three.',
              cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
              candidates: [
                for (final e in elims) CandidateMark(e.cell, z, HighlightRole.eliminate),
              ],
            ),
          ],
        );
      }
    }
  }
  return null;
}
