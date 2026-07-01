import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/puzzle.dart';
import '../data/variant_spec.dart';
import '../engine/constraints/killer_cage.dart';
import '../engine/grid.dart';
import '../engine/solver.dart';
import '../engine/step.dart';

/// Which editing tool the palette is on.
enum EditorTool { givens, cage }

/// Authoring state for the visual puzzle editor: the clue digits, the killer
/// cages, and the in-progress cage selection. Validation runs the variant-aware
/// logical solver to derive the solution and confirm the puzzle is solvable with
/// the implemented techniques before it can be saved or shared.
class EditorState extends ChangeNotifier {
  final List<int> givens = List<int>.filled(cellCount, 0);
  final List<KillerCage> cages = [];

  EditorTool tool = EditorTool.givens;
  int? selectedCell;

  /// Cells collected for the cage currently being built, in tap order.
  final List<int> pendingCage = [];

  /// Set after a failed [buildPuzzle] so the UI can explain what to fix.
  String? validationError;

  VariantSpec get liveVariant =>
      VariantSpec(name: 'Killer', type: 'killer', constraints: List.of(cages));

  int cageIndexOfCell(int cell) =>
      cages.indexWhere((c) => c.cells.contains(cell));

  void setTool(EditorTool t) {
    if (tool == t) return;
    tool = t;
    pendingCage.clear();
    notifyListeners();
  }

  void selectCell(int i) {
    selectedCell = i;
    if (tool == EditorTool.cage) {
      // A cell already in a committed cage is left alone (remove the cage via
      // its chip); otherwise toggle it in the pending selection.
      if (cageIndexOfCell(i) == -1) {
        if (!pendingCage.remove(i)) pendingCage.add(i);
      }
    }
    notifyListeners();
  }

  void inputGiven(int digit) {
    final cell = selectedCell;
    if (cell == null) return;
    givens[cell] = givens[cell] == digit ? 0 : digit;
    notifyListeners();
  }

  void eraseGiven() {
    final cell = selectedCell;
    if (cell == null) return;
    givens[cell] = 0;
    notifyListeners();
  }

  void clearPendingCage() {
    pendingCage.clear();
    notifyListeners();
  }

  /// Commit the pending cells as a cage with [sum]. Returns an error message on
  /// failure, or null on success.
  String? addCage(int sum) {
    if (pendingCage.length < 2) {
      return 'Tap at least two cells for a cage.';
    }
    if (pendingCage.length > 9) {
      return 'A cage can have at most nine cells.';
    }
    final n = pendingCage.length;
    final minSum = n * (n + 1) ~/ 2; // 1+2+...+n
    final maxSum = n * (19 - n) ~/ 2; // 9+8+...+(10-n)
    if (sum < minSum || sum > maxSum) {
      return '$n cells must sum to between $minSum and $maxSum.';
    }
    cages.add(KillerCage(List<int>.from(pendingCage)..sort(), sum));
    pendingCage.clear();
    notifyListeners();
    return null;
  }

  void removeCage(int index) {
    if (index < 0 || index >= cages.length) return;
    cages.removeAt(index);
    notifyListeners();
  }

  void clearAll() {
    for (var i = 0; i < cellCount; i++) {
      givens[i] = 0;
    }
    cages.clear();
    pendingCage.clear();
    selectedCell = null;
    validationError = null;
    notifyListeners();
  }

  String get _boardString =>
      [for (final v in givens) v == 0 ? '.' : '$v'].join();

  /// Run the logical solver over the current design. On success build a
  /// [Puzzle] (deriving its solution and difficulty); on failure set
  /// [validationError] and return null.
  Puzzle? buildPuzzle(String name) {
    validationError = null;
    if (cages.isEmpty) {
      validationError = 'Add at least one cage before saving.';
      notifyListeners();
      return null;
    }
    final result = solveLogically(_boardString, constraints: List.of(cages));
    if (!result.solved) {
      validationError =
          "This puzzle can't be solved with the implemented techniques yet. "
          'Add more givens or cages, or adjust the sums.';
      notifyListeners();
      return null;
    }
    final displayName = name.trim().isEmpty ? 'Killer' : name.trim();
    return Puzzle(
      code: _randomCode(),
      board: _boardString,
      solution: result.board,
      difficulty: result.tier ?? Difficulty.easy,
      variant: VariantSpec(
        name: displayName,
        type: 'killer',
        constraints: List.of(cages),
      ),
    );
  }

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final Random _rng = Random();

  String _randomCode() =>
      List.generate(6, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();
}
