import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/constraints/pair_dot.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/engine/strategies/pair_dot.dart';

void main() {
  group('PairDot.satisfies', () {
    test('ratio (black dot) uses the factor', () {
      const d = PairDot(0, 1, PairDotKind.ratio, 2);
      expect(d.satisfies(2, 4), true);
      expect(d.satisfies(4, 2), true);
      expect(d.satisfies(3, 5), false);
    });

    test('consecutive (white dot) differs by one', () {
      const d = PairDot(0, 1, PairDotKind.consecutive);
      expect(d.satisfies(4, 5), true);
      expect(d.satisfies(5, 4), true);
      expect(d.satisfies(4, 6), false);
    });

    test('sum matches XV totals', () {
      const x = PairDot(0, 1, PairDotKind.sum, 10);
      expect(x.satisfies(3, 7), true);
      expect(x.satisfies(6, 4), true);
      expect(x.satisfies(6, 5), false);
    });
  });

  group('pairDot strategy', () {
    test('prunes digits with no valid partner', () {
      // Black dot (ratio 2) between two non-peer cells on an empty board:
      // valid pairs are {1,2},{2,4},{3,6},{4,8}. So digits 5,7,9 can never
      // participate and are removed from both cells.
      final g = CandidateGrid.fromValues(List<int>.filled(81, 0),
          constraints: const [PairDot(0, 30, PairDotKind.ratio, 2)]);
      final step = pairDot(g);
      expect(step, isNotNull);
      final elims = step!.eliminations.toSet();
      expect(elims, contains(const Elimination(0, 5)));
      expect(elims, contains(const Elimination(0, 7)));
      expect(elims, contains(const Elimination(30, 9)));
      expect(elims, isNot(contains(const Elimination(0, 2))));
      expect(elims, isNot(contains(const Elimination(0, 8))));
    });

    test('consecutive constrains a placed neighbour', () {
      // Cell 30 fixed to 5 with a white dot to non-peer cell 0: 0 must be 4 or 6.
      final values = List<int>.filled(81, 0)..[30] = 5;
      final g = CandidateGrid.fromValues(values,
          constraints: const [PairDot(0, 30, PairDotKind.consecutive)]);
      final step = pairDot(g);
      expect(step, isNotNull);
      final remaining = digitsOf(g.cands[0])
          .where((d) => !step!.eliminations.contains(Elimination(0, d)))
          .toSet();
      expect(remaining, {4, 6});
    });
  });
}
