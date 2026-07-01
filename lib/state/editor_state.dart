import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/puzzle.dart';
import '../data/variant_spec.dart';
import '../engine/constraints/arrow.dart';
import '../engine/constraints/constraint.dart';
import '../engine/constraints/killer_cage.dart';
import '../engine/constraints/thermometer.dart';
import '../engine/grid.dart';
import '../engine/solver.dart';
import '../engine/step.dart';

/// Which editing tool the palette is on.
enum EditorTool { givens, cage, thermo, arrow }

/// Authoring state for the visual puzzle editor: the clue digits and the
/// variant constraints, plus the in-progress cell selection. Validation runs the
/// variant-aware logical solver to derive the solution and confirm the puzzle is
/// solvable with the implemented techniques before it can be saved or shared.
class EditorState extends ChangeNotifier {
  final List<int> givens = List<int>.filled(cellCount, 0);
  final List<Constraint> constraints = [];

  EditorTool tool = EditorTool.givens;
  int? selectedCell;

  /// Cells collected for the constraint being built, in tap order (cage cells,
  /// or an ordered thermo/arrow path).
  final List<int> pending = [];

  /// Set after a failed [buildPuzzle] so the UI can explain what to fix.
  String? validationError;

  List<KillerCage> get cages => constraints.whereType<KillerCage>().toList();

  VariantSpec get liveVariant => VariantSpec(
      name: 'Custom', type: 'custom', constraints: List.of(constraints));

  int _cageIndexOfCell(int cell) =>
      constraints.indexWhere((c) => c is KillerCage && c.cells.contains(cell));

  void setTool(EditorTool t) {
    if (tool == t) return;
    tool = t;
    pending.clear();
    notifyListeners();
  }

  void selectCell(int i) {
    selectedCell = i;
    if (tool == EditorTool.cage) {
      // Leave a cell already in a committed cage alone (remove it via its chip);
      // otherwise toggle it in the pending selection. Cages stay disjoint.
      if (_cageIndexOfCell(i) == -1) {
        if (!pending.remove(i)) pending.add(i);
      }
    } else if (tool == EditorTool.thermo || tool == EditorTool.arrow) {
      // Ordered path — toggle membership, preserving tap order.
      if (!pending.remove(i)) pending.add(i);
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

  void clearPending() {
    pending.clear();
    notifyListeners();
  }

  /// Commit the pending cells as a cage with [sum]. Returns an error message on
  /// failure, or null on success.
  String? addCage(int sum) {
    if (pending.length < 2) return 'Tap at least two cells for a cage.';
    if (pending.length > 9) return 'A cage can have at most nine cells.';
    final n = pending.length;
    final minSum = n * (n + 1) ~/ 2; // 1+2+...+n
    final maxSum = n * (19 - n) ~/ 2; // 9+8+...+(10-n)
    if (sum < minSum || sum > maxSum) {
      return '$n cells must sum to between $minSum and $maxSum.';
    }
    constraints.add(KillerCage(List<int>.from(pending)..sort(), sum));
    pending.clear();
    notifyListeners();
    return null;
  }

  /// Commit the pending path (bulb -> tip) as a thermometer.
  String? addThermo() {
    if (pending.length < 2) return 'Tap at least two cells, bulb first.';
    constraints.add(Thermometer(List<int>.from(pending)));
    pending.clear();
    notifyListeners();
    return null;
  }

  /// Commit the pending path as an arrow: first cell is the bulb, the rest the
  /// summing path.
  String? addArrow() {
    if (pending.length < 2) return 'Tap the bulb, then the path cells.';
    constraints.add(Arrow([pending.first], pending.sublist(1)));
    pending.clear();
    notifyListeners();
    return null;
  }

  void removeConstraint(int index) {
    if (index < 0 || index >= constraints.length) return;
    constraints.removeAt(index);
    notifyListeners();
  }

  void clearAll() {
    for (var i = 0; i < cellCount; i++) {
      givens[i] = 0;
    }
    constraints.clear();
    pending.clear();
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
    if (constraints.isEmpty) {
      validationError = 'Add at least one constraint before saving.';
      notifyListeners();
      return null;
    }
    final result = solveLogically(_boardString, constraints: List.of(constraints));
    if (!result.solved) {
      validationError =
          "This puzzle can't be solved with the implemented techniques yet. "
          'Add more givens or constraints, or adjust them.';
      notifyListeners();
      return null;
    }
    final displayName = name.trim().isEmpty ? 'Custom' : name.trim();
    return Puzzle(
      code: _randomCode(),
      board: _boardString,
      solution: result.board,
      difficulty: result.tier ?? Difficulty.easy,
      variant: VariantSpec(
        name: displayName,
        type: _typeTag(),
        constraints: List.of(constraints),
      ),
    );
  }

  /// A best-effort type tag from the constraints present, for display.
  String _typeTag() {
    final kinds = constraints.map((c) => c.type).toSet();
    if (kinds.length == 1) {
      switch (kinds.first) {
        case 'killer_cage':
          return 'killer';
        case 'thermometer':
          return 'thermo';
        case 'arrow':
          return 'arrow';
      }
    }
    return 'custom';
  }

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final Random _rng = Random();

  String _randomCode() =>
      List.generate(6, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();
}
