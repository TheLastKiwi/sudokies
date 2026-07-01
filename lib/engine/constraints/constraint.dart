/// Variant-rule constraints layered on top of the classic 9x9 sudoku rules.
///
/// A [Constraint] is pure data plus validation: it names the cells it touches
/// and can say whether a (partial) grid already violates it. The *deductive*
/// logic that eliminates candidates lives in the strategy functions under
/// `strategies/` (e.g. `strategies/killer.dart`), which read the constraints
/// carried on a `CandidateGrid` — mirroring how the classic strategies are
/// plain functions over the grid. This keeps constraints serialisable and free
/// of any dependency on the solver, and lets a single constraint type expose
/// several separately-ranked techniques.
library;

import 'killer_cage.dart';

/// A single variant rule attached to a puzzle.
abstract class Constraint {
  const Constraint();

  /// Stable tag used for (de)serialisation and rendering dispatch, e.g.
  /// `killer_cage`.
  String get type;

  /// Every cell (0..80) this constraint touches — used for overlap checks in
  /// the editor and for the render overlay.
  List<int> get cells;

  /// Whether the constraint is already broken by [values] (length 81, 0 =
  /// empty). A partially-filled grid counts as violated only when no completion
  /// could satisfy the rule.
  bool isViolated(List<int> values);

  Map<String, dynamic> toJson();
}

/// Rebuild a [Constraint] from its JSON, dispatching on the `type` tag. Unknown
/// types throw so a malformed/old share string fails loudly rather than
/// silently dropping a rule.
Constraint constraintFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  switch (type) {
    case 'killer_cage':
      return KillerCage.fromJson(json);
    default:
      throw ArgumentError('Unknown constraint type "$type"');
  }
}
