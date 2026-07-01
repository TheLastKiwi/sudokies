/// Inequality (greater-than sudoku): the digit in cell [lo] must be less than
/// the digit in cell [hi], drawn as a chevron on the shared edge pointing at the
/// smaller cell. Pure data + validation; pruning lives in
/// `strategies/inequality.dart`.
library;

import 'constraint.dart';

class Inequality extends Constraint {
  /// The smaller cell (lo < hi).
  final int lo;

  /// The larger cell.
  final int hi;

  const Inequality(this.lo, this.hi);

  factory Inequality.fromJson(Map<String, dynamic> json) => Inequality(
        (json['lo'] as num).toInt(),
        (json['hi'] as num).toInt(),
      );

  @override
  String get type => 'inequality';

  @override
  List<int> get cells => [lo, hi];

  @override
  Map<String, dynamic> toJson() => {'type': type, 'lo': lo, 'hi': hi};

  @override
  bool isViolated(List<int> values) {
    final a = values[lo], b = values[hi];
    if (a == 0 || b == 0) return false;
    return a >= b;
  }
}
