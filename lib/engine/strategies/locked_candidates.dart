import '../grid.dart';
import '../step.dart';

SolveStep? pointing(CandidateGrid g) {
  for (var b = boxUnitBase; b < boxUnitBase + 9; b++) {
    for (var d = 1; d <= 9; d++) {
      final spots = g.cellsWithCandidateInUnit(b, d);
      if (spots.length < 2) continue;
      // All in one row?
      final rows = spots.map(rowOf).toSet();
      final cols = spots.map(colOf).toSet();
      int? lineUnit;
      if (rows.length == 1) {
        lineUnit = rowUnitBase + rows.first;
      } else if (cols.length == 1) {
        lineUnit = colUnitBase + cols.first;
      }
      if (lineUnit == null) continue;
      final elims = <Elimination>[];
      for (final c in units[lineUnit]) {
        if (boxOf(c) == boxOf(spots.first)) continue;
        if (g.values[c] == 0 && maskHas(g.cands[c], d)) {
          elims.add(Elimination(c, d));
        }
      }
      if (elims.isEmpty) continue;
      return SolveStep(
        strategyId: 'pointing',
        strategyName: 'Pointing Pair/Triple',
        difficultyRank: 11,
        eliminations: elims,
        stages: [
          HintStage(
            text:
                'In ${unitName(b)}, every spot for $d lies on ${unitName(lineUnit)}.',
            cells: {for (final c in spots) c: HighlightRole.base},
            candidates: [for (final c in spots) CandidateMark(c, d, HighlightRole.base)],
          ),
          HintStage(
            text:
                'So $d must be in ${unitName(b)} on that line — remove $d from the rest of ${unitName(lineUnit)}.',
            cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
            candidates: [
              for (final c in spots) CandidateMark(c, d, HighlightRole.base),
              for (final e in elims) CandidateMark(e.cell, d, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}

SolveStep? claiming(CandidateGrid g) {
  for (var line = rowUnitBase; line < boxUnitBase; line++) {
    for (var d = 1; d <= 9; d++) {
      final spots = g.cellsWithCandidateInUnit(line, d);
      if (spots.length < 2) continue;
      final boxes = spots.map(boxOf).toSet();
      if (boxes.length != 1) continue;
      final box = boxUnitBase + boxes.first;
      final elims = <Elimination>[];
      for (final c in units[box]) {
        if (unitsOfCell[c].contains(line)) continue;
        if (g.values[c] == 0 && maskHas(g.cands[c], d)) {
          elims.add(Elimination(c, d));
        }
      }
      if (elims.isEmpty) continue;
      return SolveStep(
        strategyId: 'claiming',
        strategyName: 'Claiming (Box-Line)',
        difficultyRank: 12,
        eliminations: elims,
        stages: [
          HintStage(
            text:
                'In ${unitName(line)}, every spot for $d lies in ${unitName(box)}.',
            cells: {for (final c in spots) c: HighlightRole.base},
            candidates: [for (final c in spots) CandidateMark(c, d, HighlightRole.base)],
          ),
          HintStage(
            text:
                'So $d must be in that overlap — remove $d from the rest of ${unitName(box)}.',
            cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
            candidates: [
              for (final c in spots) CandidateMark(c, d, HighlightRole.base),
              for (final e in elims) CandidateMark(e.cell, d, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}
