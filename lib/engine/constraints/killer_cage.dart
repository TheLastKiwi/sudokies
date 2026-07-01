/// Killer Sudoku cage: a set of cells whose digits are all different and sum to
/// a target. Pure data + validation; the deductive techniques live in
/// `strategies/killer.dart`.
library;

import 'constraint.dart';

class KillerCage extends Constraint {
  /// The cells (0..80) that make up the cage.
  final List<int> cageCells;

  /// The required total of the cage's digits.
  final int sum;

  const KillerCage(this.cageCells, this.sum);

  factory KillerCage.fromJson(Map<String, dynamic> json) => KillerCage(
        [for (final c in (json['cells'] as List)) (c as num).toInt()],
        (json['sum'] as num).toInt(),
      );

  @override
  String get type => 'killer_cage';

  @override
  List<int> get cells => cageCells;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'cells': cageCells,
        'sum': sum,
      };

  @override
  bool isViolated(List<int> values) {
    final placed = <int>[];
    for (final c in cageCells) {
      final v = values[c];
      if (v != 0) placed.add(v);
    }
    // No repeated digit inside the cage.
    if (placed.toSet().length != placed.length) return true;

    final placedSum = placed.fold<int>(0, (a, b) => a + b);
    final emptyCount = cageCells.length - placed.length;
    if (emptyCount == 0) return placedSum != sum;

    final remaining = sum - placedSum;
    if (remaining <= 0) return true;

    // The remaining cells need `emptyCount` distinct digits, none already used,
    // that add up to `remaining`. If that's impossible, the cage is dead.
    final used = placed.toSet();
    final avail = [for (var d = 1; d <= 9; d++) if (!used.contains(d)) d];
    if (avail.length < emptyCount) return true;
    final minSum =
        avail.take(emptyCount).fold<int>(0, (a, b) => a + b);
    final maxSum = avail
        .skip(avail.length - emptyCount)
        .fold<int>(0, (a, b) => a + b);
    return remaining < minSum || remaining > maxSum;
  }
}

/// Every ascending combination of [k] distinct digits drawn from 1..9 — but
/// never using a digit in [exclude] — that sums to [target]. Returns an empty
/// list when no combination exists. This is the core of the Killer
/// "sum combinations" technique.
List<List<int>> cageCombinations(int k, int target, {Set<int> exclude = const {}}) {
  final out = <List<int>>[];
  final current = <int>[];

  void recurse(int start, int remaining) {
    if (current.length == k) {
      if (remaining == 0) out.add(List<int>.from(current));
      return;
    }
    for (var d = start; d <= 9; d++) {
      if (exclude.contains(d)) continue;
      if (d > remaining) break; // digits only grow; can't reach target anymore
      current.add(d);
      recurse(d + 1, remaining - d);
      current.removeLast();
    }
  }

  if (k > 0 && target > 0) recurse(1, target);
  return out;
}
