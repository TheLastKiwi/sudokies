/// A relation between two orthogonally-adjacent cells, drawn as a marker on the
/// edge between them: a ratio dot (Kropki black — one is a multiple of the
/// other), a consecutive dot (Kropki white — differ by one), or a sum marker
/// (XV-style — the two add to a value). Pure data + validation; pruning lives in
/// `strategies/pair_dot.dart`.
library;

import 'constraint.dart';

enum PairDotKind { ratio, consecutive, sum }

class PairDot extends Constraint {
  final int a;
  final int b;
  final PairDotKind kind;

  /// The ratio factor (default 2 for a black dot) or the sum target (e.g. 10 for
  /// an X, 5 for a V). Unused for [PairDotKind.consecutive].
  final int value;

  const PairDot(this.a, this.b, this.kind, [this.value = 0]);

  factory PairDot.fromJson(Map<String, dynamic> json) => PairDot(
        (json['a'] as num).toInt(),
        (json['b'] as num).toInt(),
        PairDotKind.values.firstWhere((k) => k.name == json['kind'],
            orElse: () => PairDotKind.ratio),
        (json['value'] as num?)?.toInt() ?? 0,
      );

  int get _factor => value == 0 ? 2 : value;

  /// Whether digits [x] and [y] (either assignment order) satisfy the relation.
  bool satisfies(int x, int y) {
    switch (kind) {
      case PairDotKind.ratio:
        return x == _factor * y || y == _factor * x;
      case PairDotKind.consecutive:
        return (x - y).abs() == 1;
      case PairDotKind.sum:
        return x + y == value;
    }
  }

  @override
  String get type => 'pair_dot';

  @override
  List<int> get cells => [a, b];

  @override
  Map<String, dynamic> toJson() =>
      {'type': type, 'a': a, 'b': b, 'kind': kind.name, 'value': value};

  @override
  bool isViolated(List<int> values) {
    final x = values[a], y = values[b];
    if (x == 0 || y == 0) return false; // partial — nothing to check yet
    return !satisfies(x, y);
  }
}
