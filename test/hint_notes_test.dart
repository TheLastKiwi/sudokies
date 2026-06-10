import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/hint.dart';

void main() {
  // A solvable board with many empties so basic-candidate fallback would
  // easily find a single. Givens taken from a standard easy puzzle.
  final values = <int>[
    5, 3, 0, 0, 7, 0, 0, 0, 0, //
    6, 0, 0, 1, 9, 5, 0, 0, 0, //
    0, 9, 8, 0, 0, 0, 0, 6, 0, //
    8, 0, 0, 0, 6, 0, 0, 0, 3, //
    4, 0, 0, 8, 0, 3, 0, 0, 1, //
    7, 0, 0, 0, 2, 0, 0, 0, 6, //
    0, 6, 0, 0, 0, 0, 2, 8, 0, //
    0, 0, 0, 4, 1, 9, 0, 0, 5, //
    0, 0, 0, 0, 8, 0, 0, 7, 9, //
  ];

  test('no notes → no hint', () {
    final noNotes = List<int>.filled(cellCount, 0);
    expect(nextHint(values, noNotes), isNull);
  });

  test('full notes → a hint is found', () {
    final full = List<int>.filled(cellCount, allMask);
    expect(nextHint(values, full), isNotNull);
  });

  test('no notes arg (legacy) → still falls back to basic', () {
    // Passing no notes keeps the old behaviour for the example replay path.
    expect(nextHint(values), isNotNull);
  });
}
