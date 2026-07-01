import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/constraints/inequality.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/strategies/inequality.dart';

void main() {
  List<int> board(Map<int, int> placed) {
    final v = List<int>.filled(81, 0);
    placed.forEach((k, val) => v[k] = val);
    return v;
  }

  group('Inequality', () {
    test('isViolated only when both placed and out of order', () {
      const ineq = Inequality(0, 1);
      expect(ineq.isViolated(board({0: 3, 1: 7})), false);
      expect(ineq.isViolated(board({0: 7, 1: 3})), true);
      expect(ineq.isViolated(board({0: 5, 1: 5})), true);
      expect(ineq.isViolated(board({0: 5})), false); // partial
    });
  });

  group('inequality strategy', () {
    test('bounds both cells against a placed neighbour', () {
      // lo(0) < hi(30), hi placed to 4 -> lo must be < 4 (remove 4..9).
      final g = CandidateGrid.fromValues(board({30: 4}),
          constraints: const [Inequality(0, 30)]);
      final step = inequality(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      expect(elims, contains(const Elimination(0, 4)));
      expect(elims, contains(const Elimination(0, 9)));
      expect(elims, isNot(contains(const Elimination(0, 3))));
    });

    test('bounds the larger cell above the smaller', () {
      // lo(0) placed to 6 -> hi(30) must be > 6 (remove 1..6).
      final g = CandidateGrid.fromValues(board({0: 6}),
          constraints: const [Inequality(0, 30)]);
      final step = inequality(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      expect(elims, contains(const Elimination(30, 6)));
      expect(elims, contains(const Elimination(30, 1)));
      expect(elims, isNot(contains(const Elimination(30, 7))));
    });
  });
}
