import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../engine/step.dart';

/// One technique entry with a mined example board for the teaching hint and the
/// techniques bank screen.
class TechniqueInfo {
  final String id;
  final String name;
  final Difficulty tier;
  final int rank;
  final String description;
  final String exampleBoard; // 81 chars, '' if none mined

  const TechniqueInfo({
    required this.id,
    required this.name,
    required this.tier,
    required this.rank,
    required this.description,
    required this.exampleBoard,
  });

  bool get hasExample => exampleBoard.length == 81;

  List<int> get exampleValues => hasExample
      ? [for (final ch in exampleBoard.split('')) ch == '.' ? 0 : int.parse(ch)]
      : const [];
}

/// Loads the mined technique metadata bundled as an asset.
class TechniqueLibrary {
  final List<TechniqueInfo> techniques;
  final Map<String, TechniqueInfo> _byId;

  TechniqueLibrary(this.techniques)
      : _byId = {for (final t in techniques) t.id: t};

  static Future<TechniqueLibrary> load() async {
    final raw = await rootBundle.loadString('assets/techniques.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['techniques'] as List?) ?? const [];
    final techniques = [
      for (final t in list)
        TechniqueInfo(
          id: t['id'] as String,
          name: t['name'] as String,
          tier: difficultyFromId(t['tier'] as String),
          rank: (t['rank'] as num).toInt(),
          description: t['description'] as String,
          exampleBoard: (t['exampleBoard'] as String?) ?? '',
        ),
    ]..sort((a, b) => a.rank.compareTo(b.rank));
    return TechniqueLibrary(techniques);
  }

  TechniqueInfo? byId(String id) => _byId[id];
}
