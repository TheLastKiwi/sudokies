import '../engine/constraints/constraint.dart';

/// Describes the variant rules attached to a puzzle: a human-readable name, a
/// type tag (e.g. `killer`), the list of [Constraint]s, and — reserved for
/// future region variants like diagonal/windoku/anti-knight — extra
/// all-different unit groups. A classic puzzle has no [VariantSpec] at all.
class VariantSpec {
  final String name;
  final String type;
  final List<Constraint> constraints;

  /// Extra all-different groups (each a list of cell indices). Empty for the
  /// variants shipped so far; the field reserves room in the format so region
  /// variants can be added without a breaking schema change.
  final List<List<int>> extraUnits;

  const VariantSpec({
    required this.name,
    required this.type,
    this.constraints = const [],
    this.extraUnits = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'constraints': [for (final c in constraints) c.toJson()],
        if (extraUnits.isNotEmpty) 'extraUnits': extraUnits,
      };

  factory VariantSpec.fromJson(Map<String, dynamic> json) => VariantSpec(
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'custom',
        constraints: [
          for (final c in (json['constraints'] as List? ?? const []))
            constraintFromJson(Map<String, dynamic>.from(c as Map))
        ],
        extraUnits: [
          for (final u in (json['extraUnits'] as List? ?? const []))
            [for (final c in (u as List)) (c as num).toInt()]
        ],
      );
}
