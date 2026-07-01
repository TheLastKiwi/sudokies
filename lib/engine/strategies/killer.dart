/// Killer Sudoku techniques. Each reads the [KillerCage] constraints carried on
/// the grid and short-circuits when the grid has no constraints, so classic
/// puzzles (and every classic test) are wholly unaffected.
library;

import '../constraints/killer_cage.dart';
import '../grid.dart';
import '../step.dart';

Iterable<KillerCage> _cages(CandidateGrid g) =>
    g.constraints.whereType<KillerCage>();

int _placedSum(CandidateGrid g, KillerCage cage) {
  var s = 0;
  for (final c in cage.cells) {
    s += g.values[c];
  }
  return s;
}

/// A cage with a single empty cell forces that cell to `sum − (placed total)`.
SolveStep? killerLastCell(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final cage in _cages(g)) {
    final empties = [for (final c in cage.cells) if (g.values[c] == 0) c];
    if (empties.length != 1) continue;
    final cell = empties.first;
    final d = cage.sum - _placedSum(g, cage);
    if (d < 1 || d > 9 || !maskHas(g.cands[cell], d)) continue;
    return SolveStep(
      strategyId: 'killer_last_cell',
      strategyName: 'Cage Last Cell',
      difficultyRank: 3,
      placements: [Placement(cell, d)],
      stages: [
        HintStage(
          text: 'This cage of ${cage.cells.length} cells sums to ${cage.sum} '
              'and has one empty cell left.',
          cells: {for (final c in cage.cells) c: HighlightRole.base},
        ),
        HintStage(
          text: 'The filled cells already total ${cage.sum - d}, so '
              '${cellName(cell)} must be $d.',
          cells: {cell: HighlightRole.place},
        ),
      ],
    );
  }
  return null;
}

/// A cage's digits are all different, so a digit placed in the cage can be
/// removed from every other empty cell of the same cage.
SolveStep? killerNoRepeat(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final cage in _cages(g)) {
    final placedDigits = <int>{
      for (final c in cage.cells) if (g.values[c] != 0) g.values[c]
    };
    if (placedDigits.isEmpty) continue;
    final elims = <Elimination>{};
    for (final c in cage.cells) {
      if (g.values[c] != 0) continue;
      for (final d in placedDigits) {
        if (maskHas(g.cands[c], d)) elims.add(Elimination(c, d));
      }
    }
    if (elims.isEmpty) continue;
    return SolveStep(
      strategyId: 'killer_no_repeat',
      strategyName: 'Cage No-Repeat',
      difficultyRank: 6,
      eliminations: elims.toList(),
      stages: [
        HintStage(
          text: 'A cage never repeats a digit. This cage already contains '
              '${(placedDigits.toList()..sort()).join(', ')}.',
          cells: {for (final c in cage.cells) c: HighlightRole.base},
        ),
        HintStage(
          text: 'Remove those digits from the cage\'s other cells.',
          cells: {
            for (final e in elims) e.cell: HighlightRole.eliminate,
          },
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

/// The empty cells of a cage must together form a distinct-digit combination
/// summing to the remaining total. Any candidate that appears in no such
/// combination can be eliminated.
SolveStep? killerCageSums(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final cage in _cages(g)) {
    final empties = [for (final c in cage.cells) if (g.values[c] == 0) c];
    if (empties.isEmpty) continue;
    final used = <int>{
      for (final c in cage.cells) if (g.values[c] != 0) g.values[c]
    };
    final remaining = cage.sum - _placedSum(g, cage);
    final combos = cageCombinations(empties.length, remaining, exclude: used);
    if (combos.isEmpty) continue; // broken cage — don't nuke every candidate
    var unionMask = 0;
    for (final combo in combos) {
      for (final d in combo) {
        unionMask |= maskOf(d);
      }
    }
    final elims = <Elimination>[];
    for (final c in empties) {
      for (final d in digitsOf(g.cands[c] & ~unionMask)) {
        elims.add(Elimination(c, d));
      }
    }
    if (elims.isEmpty) continue;
    final comboText = combos.length <= 6
        ? combos.map((c) => c.join('+')).join(', ')
        : '${combos.length} combinations';
    return SolveStep(
      strategyId: 'killer_cage_sums',
      strategyName: 'Cage Sum Combinations',
      difficultyRank: 15,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'The ${empties.length} empty cells of this cage must sum to '
              '$remaining: $comboText.',
          cells: {for (final c in cage.cells) c: HighlightRole.base},
        ),
        HintStage(
          text: 'Digits appearing in no valid combination can be removed.',
          cells: {
            for (final e in elims) e.cell: HighlightRole.eliminate,
          },
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
