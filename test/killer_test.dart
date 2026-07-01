import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/data/puzzle.dart';
import 'package:sudokies/data/variant_spec.dart';
import 'package:sudokies/engine/brute_solver.dart';
import 'package:sudokies/engine/constraints/constraint.dart';
import 'package:sudokies/engine/constraints/killer_cage.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/hint.dart';
import 'package:sudokies/engine/solver.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/strategies/killer.dart';
import 'package:sudokies/engine/strategies/strategy.dart';

/// Run the integrated logical solver loop (all strategies, cheapest-first) over
/// a constrained grid and return the resulting board string.
String _solveToString(String puzzle, List<Constraint> constraints) {
  final g = CandidateGrid.fromString(puzzle, constraints: constraints);
  for (var steps = 0; steps < 1000 && !g.isSolved; steps++) {
    SolveStep? step;
    for (final s in allStrategies) {
      step = s.apply(g);
      if (step != null && !step.isEmpty) break;
      step = null;
    }
    if (step == null) break;
    for (final p in step.placements) {
      if (g.values[p.cell] == 0) g.place(p.cell, p.digit);
    }
    for (final e in step.eliminations) {
      g.eliminate(e.cell, e.digit);
    }
  }
  return g.toBoardString();
}

void main() {
  group('cageCombinations', () {
    test('distinct-digit combinations summing to a target', () {
      expect(cageCombinations(2, 5), [
        [1, 4],
        [2, 3],
      ]);
      expect(cageCombinations(3, 7), [
        [1, 2, 4],
      ]);
      expect(cageCombinations(1, 5), [
        [5],
      ]);
    });

    test('honours the exclude set', () {
      expect(cageCombinations(2, 5, exclude: {2}), [
        [1, 4],
      ]);
    });

    test('impossible targets yield nothing', () {
      expect(cageCombinations(2, 100), isEmpty);
      expect(cageCombinations(2, 1), isEmpty);
    });
  });

  group('KillerCage.isViolated', () {
    List<int> board(Map<int, int> placed) {
      final v = List<int>.filled(81, 0);
      placed.forEach((k, val) => v[k] = val);
      return v;
    }

    test('complete cage checks the exact sum', () {
      const cage = KillerCage([0, 1], 10);
      expect(cage.isViolated(board({0: 4, 1: 6})), false);
      expect(cage.isViolated(board({0: 4, 1: 7})), true);
    });

    test('repeated digit is a violation', () {
      const cage = KillerCage([0, 1], 8);
      expect(cage.isViolated(board({0: 4, 1: 4})), true);
    });

    test('partial cage is fine while the target is still reachable', () {
      const cage = KillerCage([0, 1], 10);
      expect(cage.isViolated(board({0: 4})), false);
    });

    test('partial cage that can no longer reach its target is violated', () {
      // Three cells summing to 10 with a 9 placed: the other two distinct
      // digits (min 1+2=3) already overshoot the remaining 1.
      const cage = KillerCage([0, 1, 2], 10);
      expect(cage.isViolated(board({0: 9})), true);
    });
  });

  group('killer strategies', () {
    test('last cell forces the missing digit', () {
      final values = List<int>.filled(81, 0)..[0] = 4;
      final g = CandidateGrid.fromValues(values,
          constraints: const [KillerCage([0, 1], 10)]);
      final step = killerLastCell(g);
      expect(step, isNotNull);
      expect(step!.placements.single.cell, 1);
      expect(step.placements.single.digit, 6);
    });

    test('no-repeat removes a placed digit from non-peer cage cells', () {
      // Cells 0 (r1c1) and 21 (r3c4) are not peers, so classic elimination
      // leaves 5 as a candidate at 21 — only the cage rules it out.
      final values = List<int>.filled(81, 0)..[0] = 5;
      final g = CandidateGrid.fromValues(values,
          constraints: const [KillerCage([0, 21], 9)]);
      expect(maskHas(g.cands[21], 5), true, reason: 'not classically removed');
      final step = killerNoRepeat(g);
      expect(step, isNotNull);
      expect(step!.eliminations, contains(const Elimination(21, 5)));
    });

    test('cage sums restrict candidates to the valid union', () {
      // Two empty cells summing to 5 -> combos {1,4},{2,3} -> union {1,2,3,4}.
      final g = CandidateGrid.fromValues(List<int>.filled(81, 0),
          constraints: const [KillerCage([0, 21], 5)]);
      final step = killerCageSums(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      expect(elims, contains(const Elimination(0, 9)));
      expect(elims, contains(const Elimination(21, 5)));
      expect(elims, isNot(contains(const Elimination(0, 4))));
      expect(elims, isNot(contains(const Elimination(0, 1))));
    });
  });

  group('integrated solve', () {
    const easy =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

    test('a killer puzzle solves via the logical solver', () {
      final solution = BruteSolver.solve(easy)!;
      // A cage consistent with the true solution must not obstruct solving.
      final cageSum = solution[0].codeUnitAt(0) -
          48 +
          (solution[1].codeUnitAt(0) - 48) +
          (solution[2].codeUnitAt(0) - 48);
      final cage = KillerCage(const [0, 1, 2], cageSum);
      expect(_solveToString(easy, [cage]), solution);
      final result = solveLogically(easy, constraints: [cage]);
      expect(result.solved, true);
      expect(result.tier, isNotNull);
    });

    test('adding the constraints field leaves classic solving unchanged', () {
      final result = solveLogically(easy);
      expect(result.solved, true);
    });
  });

  group('hint plumbing', () {
    test('nextHint threads constraints so a cage fires where classic is stuck',
        () {
      final values = List<int>.filled(81, 0);
      final notes = List<int>.filled(81, allMask);
      // An empty, fully-noted board exposes no classic technique...
      expect(nextHint(values, notes), isNull);
      // ...but a cage's sum combinations do make progress.
      final step = nextHint(values, notes, const [KillerCage([0, 21], 5)]);
      expect(step, isNotNull);
      expect(step!.strategyId, 'killer_cage_sums');
    });
  });

  group('share string', () {
    test('classic puzzle round-trips through encode/decode', () {
      final p = Puzzle(
        code: 'ABC123',
        board: '.' * 81,
        solution: '1' * 81,
        difficulty: Difficulty.easy,
      );
      final back = Puzzle.decode(p.encode());
      expect(back.code, p.code);
      expect(back.board, p.board);
      expect(back.solution, p.solution);
      expect(back.difficulty, p.difficulty);
      expect(back.variant, isNull);
    });

    test('killer puzzle round-trips its cages', () {
      final p = Puzzle(
        code: 'KILLER',
        board: '.' * 81,
        solution: '1' * 81,
        difficulty: Difficulty.medium,
        variant: const VariantSpec(
          name: 'Killer',
          type: 'killer',
          constraints: [KillerCage([0, 1, 2], 12)],
        ),
      );
      final back = Puzzle.decode(p.encode());
      expect(back.isVariant, true);
      expect(back.variant!.type, 'killer');
      final cages = back.variant!.constraints.whereType<KillerCage>().toList();
      expect(cages, hasLength(1));
      expect(cages.single.cells, [0, 1, 2]);
      expect(cages.single.sum, 12);
    });
  });
}
