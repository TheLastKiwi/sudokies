import '../grid.dart';
import '../step.dart';

SolveStep? fullHouse(CandidateGrid g) {
  for (var u = 0; u < units.length; u++) {
    final empties = [for (final c in units[u]) if (g.values[c] == 0) c];
    if (empties.length != 1) continue;
    final cell = empties.first;
    final d = singleDigit(g.cands[cell]);
    if (d == 0) continue;
    return SolveStep(
      strategyId: 'full_house',
      strategyName: 'Full House',
      difficultyRank: 0,
      placements: [Placement(cell, d)],
      stages: [
        HintStage(
          text: '${unitName(u)} has only one empty cell left.',
          cells: {for (final c in units[u]) c: HighlightRole.base},
        ),
        HintStage(
          text: 'The only missing digit is $d, so ${cellName(cell)} = $d.',
          cells: {cell: HighlightRole.place},
        ),
      ],
    );
  }
  return null;
}

SolveStep? nakedSingle(CandidateGrid g) {
  for (var i = 0; i < cellCount; i++) {
    if (g.values[i] != 0) continue;
    final d = singleDigit(g.cands[i]);
    if (d == 0) continue;
    return SolveStep(
      strategyId: 'naked_single',
      strategyName: 'Naked Single',
      difficultyRank: 1,
      placements: [Placement(i, d)],
      stages: [
        HintStage(
          text: '${cellName(i)} has only one candidate remaining.',
          cells: {i: HighlightRole.base},
          candidates: [CandidateMark(i, d, HighlightRole.base)],
        ),
        HintStage(
          text: 'Place $d in ${cellName(i)}.',
          cells: {i: HighlightRole.place},
        ),
      ],
    );
  }
  return null;
}

SolveStep? hiddenSingle(CandidateGrid g) {
  for (var u = 0; u < units.length; u++) {
    for (var d = 1; d <= 9; d++) {
      final spots = g.cellsWithCandidateInUnit(u, d);
      if (spots.length != 1) continue;
      final cell = spots.first;
      // Skip if it's actually a naked single (only one candidate) — let the
      // easier technique own it, but it's still valid here.
      if (popcount(g.cands[cell]) == 1) continue;
      return SolveStep(
        strategyId: 'hidden_single',
        strategyName: 'Hidden Single',
        difficultyRank: 5,
        placements: [Placement(cell, d)],
        stages: [
          HintStage(
            text: 'Look at where $d can go in ${unitName(u)}.',
            cells: {for (final c in units[u]) c: HighlightRole.base},
          ),
          HintStage(
            text:
                '$d fits in only one cell of ${unitName(u)}: ${cellName(cell)}.',
            cells: {cell: HighlightRole.place},
            candidates: [CandidateMark(cell, d, HighlightRole.place)],
          ),
          HintStage(
            text: 'Place $d in ${cellName(cell)}.',
            cells: {cell: HighlightRole.place},
          ),
        ],
      );
    }
  }
  return null;
}
