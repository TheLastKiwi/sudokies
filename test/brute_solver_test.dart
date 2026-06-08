import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/brute_solver.dart';

void main() {
  group('grid tables', () {
    test('every cell has 20 peers', () {
      for (var i = 0; i < cellCount; i++) {
        expect(peers[i].length, 20, reason: 'cell $i');
      }
    });

    test('peers share a unit and exclude self', () {
      expect(peers[0], isNot(contains(0)));
      // r1c1 peers include r1c2 (row), r2c1 (col), r2c2 (box).
      expect(peers[0], containsAll(<int>[1, 9, 10]));
      // r1c1 and r5c5 share no unit.
      expect(peers[0], isNot(contains(rowOf(40) * 9 + colOf(40))));
    });

    test('there are 27 units of 9 cells', () {
      expect(units.length, 27);
      for (final u in units) {
        expect(u.length, 9);
      }
    });
  });

  group('bit helpers', () {
    test('digitsOf and popcount', () {
      expect(digitsOf(allMask), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(popcount(allMask), 9);
      expect(singleDigit(maskOf(7)), 7);
      expect(singleDigit(maskOf(3) | maskOf(8)), 0);
    });
  });

  group('brute solver', () {
    const easy =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

    bool isValidSolution(String s, String puzzle) {
      if (s.length != 81 || s.contains('0') || s.contains('.')) return false;
      for (final unit in units) {
        final seen = <String>{};
        for (final c in unit) {
          if (!seen.add(s[c])) return false;
        }
      }
      // Givens preserved.
      for (var i = 0; i < 81; i++) {
        final g = puzzle[i];
        if (g != '0' && g != '.' && s[i] != g) return false;
      }
      return true;
    }

    test('solves a known puzzle into a valid grid', () {
      final s = BruteSolver.solve(easy)!;
      expect(isValidSolution(s, easy), true);
    });

    test('unique puzzle has exactly one solution', () {
      expect(BruteSolver.countSolutions(easy), 1);
    });

    test('empty grid has many solutions (capped at 2)', () {
      expect(BruteSolver.countSolutions('.' * 81), 2);
    });

    test('CandidateGrid round-trips a board string', () {
      final normalized = easy.replaceAll('0', '.');
      final g = CandidateGrid.fromString(easy);
      expect(g.toBoardString(), normalized);
      expect(g.isSolved, false);
    });
  });
}
