/// On-the-fly Killer Sudoku generation. Build a full solution, carve it into
/// contiguous all-different cages, then keep only partitions the logical solver
/// can crack with the implemented Killer techniques (usually with no givens).
library;

import 'dart:math';

import '../data/puzzle.dart';
import '../data/variant_spec.dart';
import 'constraints/killer_cage.dart';
import 'generator.dart';
import 'grid.dart';
import 'solver.dart';
import 'step.dart';

/// Orthogonal neighbours of [cell] (up/down/left/right), ignoring the grid edge.
List<int> _neighbours(int cell) {
  final r = rowOf(cell), c = colOf(cell);
  final out = <int>[];
  if (r > 0) out.add(cell - 9);
  if (r < 8) out.add(cell + 9);
  if (c > 0) out.add(cell - 1);
  if (c < 8) out.add(cell + 1);
  return out;
}

class KillerGenerator {
  final Random _rng;
  KillerGenerator([int? seed]) : _rng = Random(seed);

  /// Carve all 81 cells into contiguous cages of up to [maxSize] cells. Growth
  /// never adds a cell whose solution digit already appears in the cage, so
  /// every cage is guaranteed all-different (the Killer rule) for [solution].
  /// Leftover cells boxed in by their neighbours become 1-cell cages.
  List<KillerCage> _carve(String solution, {int maxSize = 4}) {
    final sol = [for (var i = 0; i < cellCount; i++) solution.codeUnitAt(i) - 48];
    final cageOf = List<int>.filled(cellCount, -1);
    final cages = <List<int>>[];
    final order = List<int>.generate(cellCount, (i) => i)..shuffle(_rng);
    for (final seed in order) {
      if (cageOf[seed] != -1) continue;
      final id = cages.length;
      final cage = <int>[seed];
      final digits = <int>{sol[seed]};
      cageOf[seed] = id;
      final target = 2 + _rng.nextInt(maxSize - 1); // 2..maxSize
      while (cage.length < target) {
        final frontier = <int>[];
        for (final c in cage) {
          for (final n in _neighbours(c)) {
            if (cageOf[n] == -1 &&
                !digits.contains(sol[n]) &&
                !frontier.contains(n)) {
              frontier.add(n);
            }
          }
        }
        if (frontier.isEmpty) break;
        final pick = frontier[_rng.nextInt(frontier.length)];
        cageOf[pick] = id;
        cage.add(pick);
        digits.add(sol[pick]);
      }
      cages.add(cage);
    }
    return [
      for (final cage in cages)
        KillerCage(
          List<int>.of(cage)..sort(),
          cage.fold<int>(0, (s, c) => s + sol[c]),
        ),
    ];
  }

  /// Generate a Killer puzzle solvable with the implemented techniques.
  ///
  /// Tries up to [maxAttempts] fresh carvings of fresh solutions; the first that
  /// the logical solver cracks (from an empty board) is returned. If none do —
  /// unlikely — the final attempt is retried with a handful of givens revealed
  /// so the result is always playable and correctly graded. Larger [maxSize]
  /// cages tend to produce harder puzzles, spreading the bank across tiers.
  Puzzle generate({int maxAttempts = 200, int maxSize = 4}) {
    late String solution;
    late List<KillerCage> cages;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      solution = Generator(_rng.nextInt(1 << 31)).fullSolution();
      cages = _carve(solution, maxSize: maxSize);
      final result = solveLogically('.' * cellCount, constraints: cages);
      if (result.solved) {
        return _build(solution, cages, result.tier ?? Difficulty.easy);
      }
    }
    // Fallback: reveal a few givens so the last carving becomes solvable.
    final board = _withGivens(solution, count: 8);
    final result = solveLogically(board, constraints: cages);
    return _build(solution, cages, result.tier ?? Difficulty.medium,
        board: result.solved ? board : ('.' * cellCount));
  }

  String _withGivens(String solution, {required int count}) {
    final cells = List<int>.generate(cellCount, (i) => i)..shuffle(_rng);
    final board = List<String>.filled(cellCount, '.');
    for (final c in cells.take(count)) {
      board[c] = solution[c];
    }
    return board.join();
  }

  Puzzle _build(String solution, List<KillerCage> cages, Difficulty difficulty,
      {String? board}) {
    return Puzzle(
      code: _randomCode(),
      board: board ?? ('.' * cellCount),
      solution: solution,
      difficulty: difficulty,
      variant: VariantSpec(name: 'Killer', type: 'killer', constraints: cages),
    );
  }

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  String _randomCode() =>
      List.generate(6, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();
}
