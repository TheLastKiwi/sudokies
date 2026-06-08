import '../grid.dart';
import '../step.dart';

Iterable<List<int>> _combos(List<int> items, int k) sync* {
  final n = items.length;
  if (k > n) return;
  final idx = List<int>.generate(k, (i) => i);
  while (true) {
    yield [for (final i in idx) items[i]];
    var p = k - 1;
    while (p >= 0 && idx[p] == n - k + p) {
      p--;
    }
    if (p < 0) return;
    idx[p]++;
    for (var j = p + 1; j < k; j++) {
      idx[j] = idx[j - 1] + 1;
    }
  }
}

/// Generic basic fish of size [k] for one orientation.
/// [rowBased] true: base sets are rows, cover sets are columns.
SolveStep? _fishOriented(
  CandidateGrid g,
  int k,
  bool rowBased,
  String id,
  String name,
  int rank,
) {
  for (var d = 1; d <= 9; d++) {
    // For each base line, the cross-coordinates where d is a candidate.
    final lineSpots = <int, List<int>>{}; // baseLine -> list of cross coords
    for (var line = 0; line < 9; line++) {
      final coords = <int>[];
      for (var cross = 0; cross < 9; cross++) {
        final cell = rowBased ? line * 9 + cross : cross * 9 + line;
        if (g.values[cell] == 0 && maskHas(g.cands[cell], d)) coords.add(cross);
      }
      if (coords.length >= 2 && coords.length <= k) lineSpots[line] = coords;
    }
    final baseLines = lineSpots.keys.toList();
    if (baseLines.length < k) continue;
    for (final combo in _combos(baseLines, k)) {
      final coverSet = <int>{};
      for (final l in combo) {
        coverSet.addAll(lineSpots[l]!);
      }
      if (coverSet.length != k) continue;
      // Eliminate d from cover lines outside the base lines.
      final baseSet = combo.toSet();
      final elims = <Elimination>[];
      final baseCells = <int>[];
      for (final l in combo) {
        for (final cross in lineSpots[l]!) {
          baseCells.add(rowBased ? l * 9 + cross : cross * 9 + l);
        }
      }
      for (final cross in coverSet) {
        for (var line = 0; line < 9; line++) {
          if (baseSet.contains(line)) continue;
          final cell = rowBased ? line * 9 + cross : cross * 9 + line;
          if (g.values[cell] == 0 && maskHas(g.cands[cell], d)) {
            elims.add(Elimination(cell, d));
          }
        }
      }
      if (elims.isEmpty) continue;
      final baseLabel = rowBased ? 'rows' : 'columns';
      final coverLabel = rowBased ? 'columns' : 'rows';
      return SolveStep(
        strategyId: id,
        strategyName: name,
        difficultyRank: rank,
        eliminations: elims,
        stages: [
          HintStage(
            text:
                'For digit $d, $k $baseLabel confine it to the same $k $coverLabel.',
            cells: {for (final c in baseCells) c: HighlightRole.base},
            candidates: [for (final c in baseCells) CandidateMark(c, d, HighlightRole.base)],
          ),
          HintStage(
            text:
                '$d must occupy those $coverLabel within the pattern, so remove $d elsewhere in them.',
            cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
            candidates: [
              for (final c in baseCells) CandidateMark(c, d, HighlightRole.base),
              for (final e in elims) CandidateMark(e.cell, d, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}

SolveStep? _fish(CandidateGrid g, int k, String id, String name, int rank) {
  return _fishOriented(g, k, true, id, name, rank) ??
      _fishOriented(g, k, false, id, name, rank);
}

SolveStep? xWing(CandidateGrid g) => _fish(g, 2, 'x_wing', 'X-Wing', 26);
SolveStep? swordfish(CandidateGrid g) =>
    _fish(g, 3, 'swordfish', 'Swordfish', 31);
SolveStep? jellyfish(CandidateGrid g) =>
    _fish(g, 4, 'jellyfish', 'Jellyfish', 42);
