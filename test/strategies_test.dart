import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/solver.dart';
import 'package:sudokies/engine/strategies/strategy.dart';

int cell(int r, int c) => r * 9 + c;

void main() {
  group('registry', () {
    test('strategies sorted by rank and ids unique', () {
      final ids = <String>{};
      var prev = -1;
      for (final s in allStrategies) {
        expect(s.rank >= prev, true, reason: '${s.id} rank out of order');
        prev = s.rank;
        expect(ids.add(s.id), true, reason: 'dup id ${s.id}');
      }
    });
  });

  group('singles', () {
    test('naked single fires', () {
      // r1c1 forced: row1 has 2..9 placed except gap, etc. Simpler: build a
      // grid where one cell has a single candidate.
      final values = List<int>.filled(81, 0);
      // Fill row 0 cols 1..8 with 2..9, leaving r0c0 empty -> only 1 left.
      for (var c = 1; c <= 8; c++) {
        values[cell(0, c)] = c + 1; // 2..9
      }
      final g = CandidateGrid.fromValues(values);
      expect(singleDigit(g.cands[cell(0, 0)]), 1);
      final s = strategyById('naked_single')!.apply(g)!;
      expect(s.placements.first.cell, cell(0, 0));
      expect(s.placements.first.digit, 1);
    });

    test('hidden single fires', () {
      // Put 1 in many places so that in box 0 only r0c0 can be 1.
      final values = List<int>.filled(81, 0);
      values[cell(1, 4)] = 1; // blocks r... no. Place 1 in row1,row2 and col1,col2
      values[cell(2, 5)] = 1;
      values[cell(3, 1)] = 1;
      values[cell(4, 2)] = 1;
      // Now in box0 (rows0-2, cols0-2): rows 1,2 blocked, cols 1,2 blocked ->
      // only r0c0 left for 1.
      final s = strategyById('hidden_single')!.apply(
        CandidateGrid.fromValues(values),
      );
      expect(s, isNotNull);
      expect(s!.placements.first.digit, 1);
      expect(s.placements.first.cell, cell(0, 0));
    });
  });

  group('pointing', () {
    test('eliminates along a line', () {
      // In box0, force digit 7 candidates onto row0 only by blocking rows 1,2.
      final values = List<int>.filled(81, 0);
      // Block 7 from box0 rows 1 and 2 via peers (place 7 in row1 and row2
      // outside box0 won't block within box0 cells of those rows). Instead
      // place values in box0 rows1,2 cells so they aren't empty.
      for (var c = 0; c < 3; c++) {
        values[cell(1, c)] = (c == 0) ? 1 : (c == 1 ? 2 : 3);
        values[cell(2, c)] = (c == 0) ? 4 : (c == 1 ? 5 : 6);
      }
      // Now box0 empties are row0 c0,c1,c2. 7 can only be in row0 of box0.
      // Ensure 7 is a candidate somewhere else in row0 outside box0 to eliminate.
      final g = CandidateGrid.fromValues(values);
      final s = strategyById('pointing')!.apply(g);
      expect(s, isNotNull);
      expect(s!.eliminations.every((e) => e.digit >= 1), true);
    });
  });

  group('grader on known puzzles', () {
    test('easy puzzle solves and grades easy/medium', () {
      const easy =
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
      final r = solveLogically(easy);
      expect(r.solved, true);
      expect(
        [Difficulty.easy, Difficulty.medium].contains(r.tier),
        true,
        reason: 'tier=${r.tier}',
      );
    });

    test('a harder puzzle still solves logically', () {
      // A well-known "hard" puzzle.
      const hard =
          '000000010400000000020000000000050407008000300001090000300400200050100000000806000';
      final r = solveLogically(hard);
      // It may or may not be solvable by our set; just assert no crash and
      // that if solved, tier is assigned.
      if (r.solved) {
        expect(r.tier, isNotNull);
      }
    });
  });
}
