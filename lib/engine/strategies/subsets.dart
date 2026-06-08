import '../grid.dart';
import '../step.dart';

/// Generate all k-combinations of [items].
Iterable<List<T>> _combinations<T>(List<T> items, int k) sync* {
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

SolveStep? _nakedSubset(
  CandidateGrid g,
  int k,
  String id,
  String name,
  int rank,
) {
  for (var u = 0; u < units.length; u++) {
    final empties = [
      for (final c in units[u])
        if (g.values[c] == 0 && popcount(g.cands[c]) >= 2 && popcount(g.cands[c]) <= k)
          c
    ];
    if (empties.length < k) continue;
    for (final combo in _combinations(empties, k)) {
      var union = 0;
      for (final c in combo) {
        union |= g.cands[c];
      }
      if (popcount(union) != k) continue;
      final comboSet = combo.toSet();
      final elims = <Elimination>[];
      for (final c in units[u]) {
        if (g.values[c] != 0 || comboSet.contains(c)) continue;
        for (final d in digitsOf(union & g.cands[c])) {
          elims.add(Elimination(c, d));
        }
      }
      if (elims.isEmpty) continue;
      final digits = digitsOf(union);
      return SolveStep(
        strategyId: id,
        strategyName: name,
        difficultyRank: rank,
        eliminations: elims,
        stages: [
          HintStage(
            text:
                'In ${unitName(u)}, these $k cells together use only the digits ${digits.join(', ')}.',
            cells: {for (final c in combo) c: HighlightRole.base},
            candidates: [
              for (final c in combo)
                for (final d in digitsOf(g.cands[c]))
                  CandidateMark(c, d, HighlightRole.base),
            ],
          ),
          HintStage(
            text:
                'Those $k digits are locked to those cells, so remove them from the rest of ${unitName(u)}.',
            cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
            candidates: [
              for (final e in elims) CandidateMark(e.cell, e.digit, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}

SolveStep? _hiddenSubset(
  CandidateGrid g,
  int k,
  String id,
  String name,
  int rank,
) {
  for (var u = 0; u < units.length; u++) {
    // Digits that appear as a candidate somewhere in the unit, with their spots.
    final spots = <int, List<int>>{};
    for (var d = 1; d <= 9; d++) {
      final s = g.cellsWithCandidateInUnit(u, d);
      if (s.length >= 2 && s.length <= k) spots[d] = s;
    }
    final digits = spots.keys.toList();
    if (digits.length < k) continue;
    for (final combo in _combinations(digits, k)) {
      final cellSet = <int>{};
      for (final d in combo) {
        cellSet.addAll(spots[d]!);
      }
      if (cellSet.length != k) continue;
      final comboMask = combo.fold<int>(0, (m, d) => m | maskOf(d));
      final elims = <Elimination>[];
      for (final c in cellSet) {
        for (final d in digitsOf(g.cands[c] & ~comboMask)) {
          elims.add(Elimination(c, d));
        }
      }
      if (elims.isEmpty) continue;
      return SolveStep(
        strategyId: id,
        strategyName: name,
        difficultyRank: rank,
        eliminations: elims,
        stages: [
          HintStage(
            text:
                'In ${unitName(u)}, the digits ${combo.join(', ')} can only go in these $k cells.',
            cells: {for (final c in cellSet) c: HighlightRole.base},
            candidates: [
              for (final c in cellSet)
                for (final d in combo)
                  if (maskHas(g.cands[c], d)) CandidateMark(c, d, HighlightRole.base),
            ],
          ),
          HintStage(
            text:
                'So those cells hold only ${combo.join(', ')} — remove every other candidate from them.',
            cells: {for (final c in cellSet) c: HighlightRole.eliminate},
            candidates: [
              for (final e in elims) CandidateMark(e.cell, e.digit, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}

SolveStep? nakedPair(CandidateGrid g) =>
    _nakedSubset(g, 2, 'naked_pair', 'Naked Pair', 13);
SolveStep? nakedTriple(CandidateGrid g) =>
    _nakedSubset(g, 3, 'naked_triple', 'Naked Triple', 21);
SolveStep? nakedQuad(CandidateGrid g) =>
    _nakedSubset(g, 4, 'naked_quad', 'Naked Quad', 25);
SolveStep? hiddenPair(CandidateGrid g) =>
    _hiddenSubset(g, 2, 'hidden_pair', 'Hidden Pair', 14);
SolveStep? hiddenTriple(CandidateGrid g) =>
    _hiddenSubset(g, 3, 'hidden_triple', 'Hidden Triple', 22);
