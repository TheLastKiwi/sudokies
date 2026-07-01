import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/constraints/arrow.dart';
import 'package:sudokies/engine/constraints/thermometer.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/solver.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/strategies/thermo_arrow.dart';

void main() {
  List<int> board(Map<int, int> placed) {
    final v = List<int>.filled(81, 0);
    placed.forEach((k, val) => v[k] = val);
    return v;
  }

  group('Thermometer', () {
    // Non-peer cells so classic elimination doesn't mask the thermo bounds.
    const cells = [0, 30, 60];

    test('bounds each cell by its position on an empty board', () {
      final g = CandidateGrid.fromValues(List<int>.filled(81, 0),
          constraints: const [Thermometer(cells)]);
      final step = thermometer(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      expect(elims, contains(const Elimination(0, 9))); // bulb max is 7
      expect(elims, contains(const Elimination(0, 8)));
      expect(elims, contains(const Elimination(60, 1))); // tip min is 3
      expect(elims, contains(const Elimination(60, 2)));
      expect(elims, isNot(contains(const Elimination(0, 7))));
    });

    test('isViolated catches non-increasing and gap violations', () {
      const t = Thermometer([0, 1, 2]);
      expect(t.isViolated(board({0: 1, 1: 2, 2: 3})), false);
      expect(t.isViolated(board({0: 3, 1: 2})), true); // decreasing
      expect(t.isViolated(board({0: 1, 2: 2})), true); // gap too small
    });
  });

  group('Arrow', () {
    const bulb = [0];
    const path = [30, 60];

    test('bounds bulb and path by the achievable sum', () {
      final g = CandidateGrid.fromValues(List<int>.filled(81, 0),
          constraints: const [Arrow(bulb, path)]);
      final step = arrow(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      // Two path cells sum to at least 2, so the bulb can't be 1.
      expect(elims, contains(const Elimination(0, 1)));
      expect(elims, isNot(contains(const Elimination(0, 2))));
      // A path cell of 9 would force a sum > 9, impossible for a 1-digit bulb.
      expect(elims, contains(const Elimination(30, 9)));
      expect(elims, isNot(contains(const Elimination(30, 8))));
    });

    test('isViolated checks the sum when all cells are placed', () {
      const a = Arrow([0], [1, 2]);
      expect(a.isViolated(board({0: 5, 1: 2, 2: 3})), false);
      expect(a.isViolated(board({0: 5, 1: 2, 2: 2})), true);
    });
  });

  group('integration', () {
    const easy =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

    test('a consistent thermometer does not break classic solving', () {
      // Solution digits at 0,30,60 are 5, 7, 2 — not increasing, so use cells
      // whose solution values do increase along the path.
      final result = solveLogically(easy,
          constraints: const [Thermometer([2, 4, 6])]);
      expect(result.solved, true);
    });
  });
}
