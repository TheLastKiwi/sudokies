import 'package:flutter/material.dart';

import '../app.dart';
import '../data/technique_library.dart';
import '../engine/grid.dart';
import '../engine/hint.dart';
import '../engine/step.dart';
import 'board_widget.dart';

class TechniquesScreen extends StatelessWidget {
  const TechniquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final byTier = <Difficulty, List<TechniqueInfo>>{
      for (final d in Difficulty.values) d: [],
    };
    for (final t in library.techniques) {
      byTier[t.tier]!.add(t);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Techniques')),
      body: ListView(
        children: [
          for (final d in Difficulty.values)
            if (byTier[d]!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(d.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              for (final t in byTier[d]!)
                ListTile(
                  title: Text(t.name),
                  subtitle: Text(t.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: t.hasExample
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.info_outline, size: 18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TechniqueDetailScreen(info: t)),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class TechniqueDetailScreen extends StatefulWidget {
  final TechniqueInfo info;
  const TechniqueDetailScreen({super.key, required this.info});

  @override
  State<TechniqueDetailScreen> createState() => _TechniqueDetailScreenState();
}

class _TechniqueDetailScreenState extends State<TechniqueDetailScreen> {
  int _stageIndex = 0;
  late final List<int> _values;
  late final List<int> _candidates;
  late final SolveStep? _step;

  @override
  void initState() {
    super.initState();
    final info = widget.info;
    if (info.hasExample) {
      _values = info.exampleValues;
      _candidates = List<int>.from(CandidateGrid.fromValues(_values).cands);
      _step = runStrategyOn(info.id, _values);
    } else {
      _values = const [];
      _candidates = const [];
      _step = null;
    }
  }

  List<HintStage> get _stages => _step?.stages ?? const [];

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final stage = _stages.isEmpty
        ? null
        : _stages[_stageIndex.clamp(0, _stages.length - 1)];
    return Scaffold(
      appBar: AppBar(title: Text(info.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(info.tier.label,
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(info.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (!info.hasExample)
            const Text('No worked example available for this technique yet.')
          else ...[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: BoardWidget(
                  values: _values,
                  candidates: _candidates,
                  givens: _values,
                  interactive: false,
                  roleCells: stage?.cells ?? const {},
                  roleCandidates: stage?.candidates ?? const [],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (stage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Step ${_stageIndex + 1}/${_stages.length}: ${stage.text}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _stageIndex > 0
                      ? () => setState(() => _stageIndex--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back'),
                ),
                TextButton.icon(
                  onPressed: _stageIndex < _stages.length - 1
                      ? () => setState(() => _stageIndex++)
                      : null,
                  label: const Text('Next'),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
