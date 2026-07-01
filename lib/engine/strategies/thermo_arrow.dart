/// Thermometer and Arrow techniques. Both short-circuit on constraint-free
/// grids so classic play is unaffected.
library;

import '../constraints/arrow.dart';
import '../constraints/thermometer.dart';
import '../grid.dart';
import '../step.dart';

/// A thermometer's digits strictly increase from bulb to tip, so each cell has
/// a lower bound (from the cells before it) and an upper bound (from the cells
/// after it). Candidates outside those bounds are removed.
SolveStep? thermometer(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final t in g.constraints.whereType<Thermometer>()) {
    final n = t.path.length;
    if (n < 2) continue;
    // Forward pass: minimum value reachable at each position.
    final lo = List<int>.filled(n, 0);
    for (var k = 0; k < n; k++) {
      final v = g.values[t.path[k]];
      final base = k == 0 ? 1 : lo[k - 1] + 1;
      lo[k] = v != 0 ? v : base;
    }
    // Backward pass: maximum value allowed at each position.
    final hi = List<int>.filled(n, 0);
    for (var k = n - 1; k >= 0; k--) {
      final v = g.values[t.path[k]];
      final cap = k == n - 1 ? 9 : hi[k + 1] - 1;
      hi[k] = v != 0 ? v : cap;
    }
    final elims = <Elimination>[];
    for (var k = 0; k < n; k++) {
      final c = t.path[k];
      if (g.values[c] != 0) continue;
      for (final d in digitsOf(g.cands[c])) {
        if (d < lo[k] || d > hi[k]) elims.add(Elimination(c, d));
      }
    }
    if (elims.isEmpty) continue;
    return SolveStep(
      strategyId: 'thermometer',
      strategyName: 'Thermometer',
      difficultyRank: 9,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'Digits increase along the thermometer, bounding each cell.',
          cells: {for (final c in t.path) c: HighlightRole.base},
        ),
        HintStage(
          text: 'Remove candidates outside each cell\'s reachable range.',
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

/// The arrow's path digits sum to the number on its bulb. Bulb candidates
/// outside the path's achievable sum range, and path candidates that can't be
/// completed to any valid bulb value, are removed.
SolveStep? arrow(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final a in g.constraints.whereType<Arrow>()) {
    if (_hasDeadCell(g, a.bulb) || _hasDeadCell(g, a.path)) continue;

    // Bulb number range (multi-cell bulb reads as a multi-digit number).
    var minB = 0, maxB = 0;
    for (final c in a.bulb) {
      minB = minB * 10 + _lowOf(g, c);
      maxB = maxB * 10 + _highOf(g, c);
    }
    // Path sum range.
    var minS = 0, maxS = 0;
    for (final c in a.path) {
      minS += _lowOf(g, c);
      maxS += _highOf(g, c);
    }

    final elims = <Elimination>[];
    // Single-cell bulb: it must equal an achievable path sum.
    if (a.bulb.length == 1 && g.values[a.bulb.first] == 0) {
      final b = a.bulb.first;
      for (final d in digitsOf(g.cands[b])) {
        if (d < minS || d > maxS) elims.add(Elimination(b, d));
      }
    }
    // Path cells: with this cell = d, can the rest still hit a bulb value?
    for (final c in a.path) {
      if (g.values[c] != 0) continue;
      for (final d in digitsOf(g.cands[c])) {
        final sMin = minS - _lowOf(g, c) + d;
        final sMax = maxS - _highOf(g, c) + d;
        if (sMax < minB || sMin > maxB) elims.add(Elimination(c, d));
      }
    }
    if (elims.isEmpty) continue;
    return SolveStep(
      strategyId: 'arrow',
      strategyName: 'Arrow Sum',
      difficultyRank: 16,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'The arrow\'s path digits add up to its bulb.',
          cells: {for (final c in a.cells) c: HighlightRole.base},
        ),
        HintStage(
          text: 'Remove digits that can\'t satisfy the arrow sum.',
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

bool _hasDeadCell(CandidateGrid g, List<int> cells) {
  for (final c in cells) {
    if (g.values[c] == 0 && g.cands[c] == 0) return true;
  }
  return false;
}

int _lowOf(CandidateGrid g, int c) =>
    g.values[c] != 0 ? g.values[c] : digitsOf(g.cands[c]).first;

int _highOf(CandidateGrid g, int c) =>
    g.values[c] != 0 ? g.values[c] : digitsOf(g.cands[c]).last;
