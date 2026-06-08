import '../grid.dart';
import '../step.dart';

/// Simple Colouring for a single digit using conjugate-pair chains.
SolveStep? simpleColouring(CandidateGrid g) {
  for (var d = 1; d <= 9; d++) {
    // Build conjugate-pair links: units where d has exactly two spots.
    final adj = <int, List<int>>{};
    for (var u = 0; u < units.length; u++) {
      final spots = g.cellsWithCandidateInUnit(u, d);
      if (spots.length == 2) {
        adj.putIfAbsent(spots[0], () => []).add(spots[1]);
        adj.putIfAbsent(spots[1], () => []).add(spots[0]);
      }
    }
    if (adj.isEmpty) continue;

    final colour = <int, int>{};
    final components = <List<int>>[];
    for (final start in adj.keys) {
      if (colour.containsKey(start)) continue;
      final comp = <int>[];
      final queue = <int>[start];
      colour[start] = 0;
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        comp.add(cur);
        for (final nb in adj[cur]!) {
          if (!colour.containsKey(nb)) {
            colour[nb] = colour[cur]! ^ 1;
            queue.add(nb);
          }
        }
      }
      if (comp.length >= 2) components.add(comp);
    }

    for (final comp in components) {
      final compSet = comp.toSet();
      final c0 = [for (final c in comp) if (colour[c] == 0) c];
      final c1 = [for (final c in comp) if (colour[c] == 1) c];

      // Rule 2: two same-coloured cells share a unit -> that colour is false.
      for (final group in [c0, c1]) {
        for (var a = 0; a < group.length; a++) {
          for (var b = a + 1; b < group.length; b++) {
            if (peers[group[a]].contains(group[b])) {
              final elims = [for (final c in group) Elimination(c, d)];
              return _colourStep(d, comp, colour, elims,
                  'Two cells of the same colour share a unit, so that colour is impossible — remove $d from all of them.');
            }
          }
        }
      }

      // Rule 4: a cell seeing both colours cannot hold d.
      final elims = <Elimination>[];
      for (var c = 0; c < cellCount; c++) {
        if (g.values[c] != 0 || !maskHas(g.cands[c], d)) continue;
        if (compSet.contains(c)) continue;
        final seesA = c0.any((x) => peers[c].contains(x));
        final seesB = c1.any((x) => peers[c].contains(x));
        if (seesA && seesB) elims.add(Elimination(c, d));
      }
      if (elims.isNotEmpty) {
        return _colourStep(d, comp, colour, elims,
            'These cells see both colours of the chain, so one colour forces $d away — remove $d from them.');
      }
    }
  }
  return null;
}

SolveStep _colourStep(
  int d,
  List<int> comp,
  Map<int, int> colour,
  List<Elimination> elims,
  String conclusion,
) {
  return SolveStep(
    strategyId: 'simple_colouring',
    strategyName: 'Simple Colouring',
    difficultyRank: 33,
    eliminations: elims,
    stages: [
      HintStage(
        text:
            'Colour the conjugate-pair chain for digit $d with two alternating colours.',
        cells: {
          for (final c in comp)
            c: colour[c] == 0 ? HighlightRole.base : HighlightRole.cover,
        },
        candidates: [
          for (final c in comp)
            CandidateMark(c, d, colour[c] == 0 ? HighlightRole.base : HighlightRole.cover),
        ],
      ),
      HintStage(
        text: conclusion,
        cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
        candidates: [for (final e in elims) CandidateMark(e.cell, d, HighlightRole.eliminate)],
      ),
    ],
  );
}
