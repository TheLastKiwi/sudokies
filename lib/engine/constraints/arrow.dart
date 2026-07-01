/// Arrow: the digits along the arrow's [path] sum to the number read off its
/// [bulb]. A single-cell bulb is a one-digit target; a multi-cell bulb reads as
/// a multi-digit number (first cell = most significant). Pure data +
/// validation; the deductive bounding lives in `strategies/thermo_arrow.dart`.
library;

import 'constraint.dart';

class Arrow extends Constraint {
  /// The bulb cell(s), most-significant first.
  final List<int> bulb;

  /// The arrow's path cells whose digits sum to the bulb number.
  final List<int> path;

  const Arrow(this.bulb, this.path);

  factory Arrow.fromJson(Map<String, dynamic> json) => Arrow(
        [for (final c in (json['bulb'] as List)) (c as num).toInt()],
        [for (final c in (json['path'] as List)) (c as num).toInt()],
      );

  @override
  String get type => 'arrow';

  @override
  List<int> get cells => [...bulb, ...path];

  @override
  Map<String, dynamic> toJson() => {'type': type, 'bulb': bulb, 'path': path};

  @override
  bool isViolated(List<int> values) {
    // Bulb number range (empty bulb cells span 1..9).
    var minB = 0, maxB = 0;
    for (final c in bulb) {
      final v = values[c];
      minB = minB * 10 + (v == 0 ? 1 : v);
      maxB = maxB * 10 + (v == 0 ? 9 : v);
    }
    // Path sum range (empty path cells span 1..9).
    var minS = 0, maxS = 0;
    for (final c in path) {
      final v = values[c];
      minS += v == 0 ? 1 : v;
      maxS += v == 0 ? 9 : v;
    }
    // No achievable overlap between the bulb number and the path sum.
    return maxS < minB || minS > maxB;
  }
}
