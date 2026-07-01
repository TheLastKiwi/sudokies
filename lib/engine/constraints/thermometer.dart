/// Thermometer: cells from the bulb to the tip must be strictly increasing.
/// Pure data + validation; the deductive bounding lives in
/// `strategies/thermo_arrow.dart`.
library;

import 'constraint.dart';

class Thermometer extends Constraint {
  /// Ordered bulb -> tip. Digits strictly increase along this sequence.
  final List<int> path;

  const Thermometer(this.path);

  factory Thermometer.fromJson(Map<String, dynamic> json) => Thermometer(
        [for (final c in (json['cells'] as List)) (c as num).toInt()],
      );

  @override
  String get type => 'thermometer';

  @override
  List<int> get cells => path;

  @override
  Map<String, dynamic> toJson() => {'type': type, 'cells': path};

  @override
  bool isViolated(List<int> values) {
    final placed = <MapEntry<int, int>>[]; // position -> value
    for (var k = 0; k < path.length; k++) {
      final v = values[path[k]];
      if (v != 0) placed.add(MapEntry(k, v));
    }
    // Strictly increasing with the right gap: value must grow by at least the
    // position gap, so v[j] - v[i] >= j - i for any placed i < j.
    for (var a = 0; a < placed.length; a++) {
      for (var b = a + 1; b < placed.length; b++) {
        if (placed[b].value - placed[a].value < placed[b].key - placed[a].key) {
          return true;
        }
      }
    }
    // Absolute position bounds: position k needs k cells below and n-1-k above.
    final n = path.length;
    for (final e in placed) {
      if (e.value < e.key + 1 || e.value > 9 - (n - 1 - e.key)) return true;
    }
    return false;
  }
}
