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
      difficultyRank: 8,
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

// ---- Rule of 45: innies & outies ------------------------------------------

/// Innie/outie decomposition of a region-group whose cells total `45 *
/// [groupCount]` (a single row/column/box is `groupCount == 1`).
///
/// Cages partition the grid, so every cage touching the region is either *fully
/// inside* it or *straddles* its border. The in-region cells of straddling cages
/// (the **innies**) must sum to `45*groupCount − Σ inside-cage sums`; the
/// out-of-region cells of those cages (the **outies**) must sum to
/// `Σ touching-cage sums − 45*groupCount`. Both identities are exact.
({List<int> innies, int innieSum, List<int> outies, int outieSum}) _innieOutie(
    CandidateGrid g, List<int> region, int groupCount) {
  final regionSet = region.toSet();
  var insideSum = 0;
  var touchingSum = 0;
  final insideCells = <int>{};
  final outies = <int>[];
  for (final cage in _cages(g)) {
    var inCount = 0;
    for (final c in cage.cells) {
      if (regionSet.contains(c)) inCount++;
    }
    if (inCount == 0) continue; // fully outside the region
    touchingSum += cage.sum;
    if (inCount == cage.cells.length) {
      insideSum += cage.sum;
      insideCells.addAll(cage.cells);
    } else {
      for (final c in cage.cells) {
        if (!regionSet.contains(c)) outies.add(c);
      }
    }
  }
  final innies = [for (final c in region) if (!insideCells.contains(c)) c];
  return (
    innies: innies,
    innieSum: 45 * groupCount - insideSum,
    outies: outies,
    outieSum: touchingSum - 45 * groupCount,
  );
}

/// Place the single empty cell of a leftover set whose members sum to [total].
/// Returns null unless exactly one of [cells] is empty and the forced digit is a
/// live candidate. Sound for any leftover set (a lone cell's value is fixed by
/// the sum regardless of how the others relate).
SolveStep? _leftoverPlacement(
  CandidateGrid g,
  List<int> cells,
  int total, {
  required String id,
  required String name,
  required int rank,
  required String explain,
}) {
  final empties = [for (final c in cells) if (g.values[c] == 0) c];
  if (empties.length != 1) return null;
  var placed = 0;
  for (final c in cells) {
    if (g.values[c] != 0) placed += g.values[c];
  }
  final cell = empties.first;
  final d = total - placed;
  if (d < 1 || d > 9 || !maskHas(g.cands[cell], d)) return null;
  return SolveStep(
    strategyId: id,
    strategyName: name,
    difficultyRank: rank,
    placements: [Placement(cell, d)],
    stages: [
      HintStage(
        text: explain,
        cells: {for (final c in cells) c: HighlightRole.base},
      ),
      HintStage(
        text: 'Every other cell of that set is filled, so ${cellName(cell)} '
            'must be $d.',
        cells: {cell: HighlightRole.place},
      ),
    ],
  );
}

/// Rule of 45 over a single unit: if the cages inside it leave exactly one
/// uncovered (innie) cell — or exactly one cage cell pokes outside (outie) — the
/// missing total forces that cell's digit.
SolveStep? killerInnie(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (var u = 0; u < units.length; u++) {
    final io = _innieOutie(g, units[u], 1);
    final label = unitName(u);
    final innie = _leftoverPlacement(
      g,
      io.innies,
      io.innieSum,
      id: 'killer_innie',
      name: '45 Rule (Single Cell)',
      rank: 12,
      explain: 'By the Rule of 45, $label sums to 45. The cages sitting wholly '
          'inside it account for ${45 - io.innieSum}, so the cell it leaves '
          'over must total ${io.innieSum}.',
    );
    if (innie != null) return innie;
    final outie = _leftoverPlacement(
      g,
      io.outies,
      io.outieSum,
      id: 'killer_innie',
      name: '45 Rule (Single Cell)',
      rank: 12,
      explain: 'By the Rule of 45, $label sums to 45. The cages covering it '
          'total ${io.outieSum + 45}, so the cell poking outside must total '
          '${io.outieSum}.',
    );
    if (outie != null) return outie;
  }
  return null;
}

/// Rule of 45 over a single unit where the innies form a 2–4 cell group of known
/// sum. Those cells share the unit (so their digits differ) — a virtual cage —
/// letting `cageCombinations` prune candidates that fit no valid combination.
SolveStep? killerInnieOutie(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (var u = 0; u < units.length; u++) {
    final io = _innieOutie(g, units[u], 1);
    final empties = [for (final c in io.innies) if (g.values[c] == 0) c];
    if (empties.length < 2 || empties.length > 4) continue;
    final used = <int>{
      for (final c in io.innies) if (g.values[c] != 0) g.values[c]
    };
    var placed = 0;
    for (final c in io.innies) {
      if (g.values[c] != 0) placed += g.values[c];
    }
    final remaining = io.innieSum - placed;
    final combos = cageCombinations(empties.length, remaining, exclude: used);
    if (combos.isEmpty) continue; // broken region — don't nuke every candidate
    var union = 0;
    for (final combo in combos) {
      for (final d in combo) {
        union |= maskOf(d);
      }
    }
    final elims = <Elimination>[];
    for (final c in empties) {
      for (final d in digitsOf(g.cands[c] & ~union)) {
        elims.add(Elimination(c, d));
      }
    }
    if (elims.isEmpty) continue;
    final comboText = combos.length <= 6
        ? combos.map((c) => c.join('+')).join(', ')
        : '${combos.length} combinations';
    return SolveStep(
      strategyId: 'killer_innie_outie',
      strategyName: '45 Rule (Innies & Outies)',
      difficultyRank: 24,
      eliminations: elims,
      stages: [
        HintStage(
          text: 'By the Rule of 45, the cells ${unitName(u)} leaves outside its '
              'inner cages must sum to $remaining: $comboText.',
          cells: {for (final c in io.innies) c: HighlightRole.base},
        ),
        HintStage(
          text: 'Digits appearing in no valid combination can be removed.',
          cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
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

/// A cage lying entirely within one unit whose empty cells can only hold exactly
/// as many distinct digits as there are cells is a locked (naked) set — a
/// "killer pair/triple". Those digits can be removed from the rest of the unit.
SolveStep? killerCageUnit(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final cage in _cages(g)) {
    final empties = [for (final c in cage.cells) if (g.values[c] == 0) c];
    if (empties.isEmpty) continue;
    for (final u in unitsOfCell[cage.cells.first]) {
      if (!cage.cells.every((c) => units[u].contains(c))) continue;
      final used = <int>{
        for (final c in cage.cells) if (g.values[c] != 0) g.values[c]
      };
      var placed = 0;
      for (final c in cage.cells) {
        if (g.values[c] != 0) placed += g.values[c];
      }
      final combos =
          cageCombinations(empties.length, cage.sum - placed, exclude: used);
      if (combos.isEmpty) continue;
      var union = 0;
      for (final combo in combos) {
        for (final d in combo) {
          union |= maskOf(d);
        }
      }
      if (popcount(union) != empties.length) continue; // not a locked set
      final elims = <Elimination>[];
      for (final c in units[u]) {
        if (g.values[c] != 0 || cage.cells.contains(c)) continue;
        for (final d in digitsOf(g.cands[c] & union)) {
          elims.add(Elimination(c, d));
        }
      }
      if (elims.isEmpty) continue;
      final digits = digitsOf(union).join(', ');
      return SolveStep(
        strategyId: 'killer_cage_unit',
        strategyName: 'Killer Pair / Locked Set',
        difficultyRank: 22,
        eliminations: elims,
        stages: [
          HintStage(
            text: 'This cage sits entirely within ${unitName(u)}, and its '
                '${empties.length} empty cells can only be $digits — exactly '
                '${empties.length} digits for ${empties.length} cells.',
            cells: {for (final c in cage.cells) c: HighlightRole.base},
          ),
          HintStage(
            text: 'Those digits are locked to the cage, so remove them from the '
                'rest of the ${unitName(u)}.',
            cells: {for (final e in elims) e.cell: HighlightRole.eliminate},
            candidates: [
              for (final e in elims)
                CandidateMark(e.cell, e.digit, HighlightRole.eliminate),
            ],
          ),
        ],
      );
    }
  }
  return null;
}

/// Contiguous groups of 2–3 aligned rows or columns, each labelled for hints.
/// A group of `g` lines totals `45 * g`, extending the Rule of 45 across a band.
List<({List<int> cells, int count, String label})> _regionGroups() {
  final groups = <({List<int> cells, int count, String label})>[];
  for (final size in const [2, 3]) {
    for (var start = 0; start + size <= 9; start++) {
      final rowCells = <int>[];
      final colCells = <int>[];
      for (var i = start; i < start + size; i++) {
        rowCells.addAll(units[rowUnitBase + i]);
        colCells.addAll(units[colUnitBase + i]);
      }
      groups.add((
        cells: rowCells,
        count: size,
        label: 'rows ${start + 1}–${start + size}',
      ));
      groups.add((
        cells: colCells,
        count: size,
        label: 'columns ${start + 1}–${start + size}',
      ));
    }
  }
  return groups;
}

/// Rule of 45 across a band of 2–3 rows or columns. When the cages inside the
/// band leave a single innie cell (or a single outie pokes out), its digit is
/// forced. Only the single-cell case is used: innies of a multi-line band are
/// not mutually visible, so combination pruning would be unsound.
SolveStep? killerBigInnie(CandidateGrid g) {
  if (g.constraints.isEmpty) return null;
  for (final grp in _regionGroups()) {
    final total = 45 * grp.count;
    final io = _innieOutie(g, grp.cells, grp.count);
    final innie = _leftoverPlacement(
      g,
      io.innies,
      io.innieSum,
      id: 'killer_big_innie',
      name: '45 Rule (Multi-Region)',
      rank: 32,
      explain: 'By the Rule of 45, ${grp.label} sum to $total. The cages wholly '
          'inside them account for ${total - io.innieSum}, so the one cell they '
          'leave over must total ${io.innieSum}.',
    );
    if (innie != null) return innie;
    final outie = _leftoverPlacement(
      g,
      io.outies,
      io.outieSum,
      id: 'killer_big_innie',
      name: '45 Rule (Multi-Region)',
      rank: 32,
      explain: 'By the Rule of 45, ${grp.label} sum to $total. The cages '
          'covering them total ${io.outieSum + total}, so the one cell poking '
          'outside must total ${io.outieSum}.',
    );
    if (outie != null) return outie;
  }
  return null;
}
