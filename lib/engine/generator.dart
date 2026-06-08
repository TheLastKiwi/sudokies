/// Offline puzzle generation: build a full solution, then dig holes while
/// keeping a unique solution. Used only by the bank-building tool.
library;

import 'dart:math';

import 'grid.dart';
import 'brute_solver.dart';

class GeneratedPuzzle {
  final String board; // 81 chars, '.' for blanks
  final String solution; // 81 digits
  const GeneratedPuzzle(this.board, this.solution);
}

class Generator {
  final Random _rng;
  Generator([int? seed]) : _rng = Random(seed);

  /// Build a random complete solution grid.
  String fullSolution() {
    final values = List<int>.filled(cellCount, 0);
    if (!_fill(values, 0)) {
      throw StateError('failed to generate a solution');
    }
    return [for (final v in values) '$v'].join();
  }

  bool _fill(List<int> values, int pos) {
    if (pos == cellCount) return true;
    if (values[pos] != 0) return _fill(values, pos + 1);
    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_rng);
    for (final d in digits) {
      if (_legal(values, pos, d)) {
        values[pos] = d;
        if (_fill(values, pos + 1)) return true;
        values[pos] = 0;
      }
    }
    return false;
  }

  bool _legal(List<int> values, int cell, int d) {
    for (final p in peers[cell]) {
      if (values[p] == d) return false;
    }
    return true;
  }

  /// Dig holes from a full [solution], removing clues greedily while the puzzle
  /// stays uniquely solvable. [symmetric] removes the 180°-rotated partner too.
  GeneratedPuzzle dig(
    String solution, {
    bool symmetric = false,
    int? maxRemovals,
  }) {
    final board = solution.split('');
    final order = List<int>.generate(cellCount, (i) => i)..shuffle(_rng);
    var removed = 0;
    for (final i in order) {
      if (maxRemovals != null && removed >= maxRemovals) break;
      if (board[i] == '.') continue;
      final partner = symmetric ? cellCount - 1 - i : i;
      final savedA = board[i];
      final savedB = board[partner];
      board[i] = '.';
      board[partner] = '.';
      final candidate = board.join();
      if (BruteSolver.countSolutions(candidate) != 1) {
        board[i] = savedA;
        board[partner] = savedB;
      } else {
        removed += (partner == i) ? 1 : 2;
      }
    }
    return GeneratedPuzzle(board.join(), solution);
  }

  /// Generate one dug puzzle from a fresh random solution.
  GeneratedPuzzle generate({bool symmetric = false, int? maxRemovals}) =>
      dig(fullSolution(), symmetric: symmetric, maxRemovals: maxRemovals);
}
