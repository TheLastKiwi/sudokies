/// Prints an encoded share string for a sample Killer puzzle, used to verify
/// the render/import flow before the in-app editor lands.
///
/// Run:  dart run tool/sample_killer.dart
library;

import 'package:sudokies/data/puzzle.dart';
import 'package:sudokies/data/variant_spec.dart';
import 'package:sudokies/engine/constraints/killer_cage.dart';
import 'package:sudokies/engine/step.dart';

void main() {
  const board =
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
  const solution =
      '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

  int sumOf(List<int> cells) =>
      cells.map((c) => solution.codeUnitAt(c) - 48).reduce((a, b) => a + b);

  final cageCells = <List<int>>[
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [9, 10],
    [11, 20, 19], // L-shape spanning two rows
    [40, 49],
    [76, 77],
  ];
  final cages = [for (final cc in cageCells) KillerCage(cc, sumOf(cc))];

  final puzzle = Puzzle(
    code: 'KILSMP',
    board: board,
    solution: solution,
    difficulty: Difficulty.easy,
    variant:
        VariantSpec(name: 'Killer', type: 'killer', constraints: cages),
  );

  print(puzzle.encode());
}
