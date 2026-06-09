import 'package:flutter/material.dart';

import '../engine/step.dart';
import '../state/game_state.dart';
import 'board_widget.dart';

/// Full-screen overlay shown while a hint is active. In the teaching phase it
/// renders the technique on an example board; pressing "Find it on my puzzle"
/// re-renders the same technique on the player's actual board.
class HintPanel extends StatelessWidget {
  final GameState game;
  const HintPanel({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final view = game.hintView;
    if (view == null) return const SizedBox.shrink();
    final stageIndex =
        view.stages.isEmpty ? 0 : game.hintStageIndex.clamp(0, view.stages.length - 1);
    final HintStage? stage = view.stages.isEmpty ? null : view.stages[stageIndex];

    // The live board is Offstage while this overlay is up, so there is nothing
    // to see through — use an opaque fill and a flat (shadowless) card. A
    // translucent full-screen layer and an elevation shadow each allocate a
    // viewport-sized offscreen surface, which trips iOS WebKit's canvas-memory
    // cap and crashes the tab when the hint board also renders.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            view.strategyName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: game.closeHint,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(view.onCurrentBoard
                            ? 'On your puzzle'
                            : 'Example puzzle'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (view.showBoard)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: BoardWidget(
                          values: view.values,
                          candidates: view.candidates,
                          givens: view.values, // example board: show all as fixed
                          interactive: false,
                          roleCells: stage?.cells ?? const {},
                          roleCandidates: stage?.candidates ?? const [],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!view.onCurrentBoard)
                      Text(view.description,
                          style: Theme.of(context).textTheme.bodySmall),
                    if (stage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Step ${stageIndex + 1}/${view.stages.length}: ${stage.text}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _controls(context, view, stageIndex),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, HintView view, int stageIndex) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: stageIndex > 0 ? game.prevHintStage : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            ),
            TextButton.icon(
              onPressed:
                  stageIndex < view.stages.length - 1 ? game.nextHintStage : null,
              label: const Text('Next'),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!view.onCurrentBoard)
          FilledButton.icon(
            onPressed: game.requestHint,
            icon: const Icon(Icons.search),
            label: const Text('Find it on my puzzle'),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: game.closeHint,
                child: const Text('Got it'),
              ),
              if (view.canApply) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: game.applyHint,
                  icon: const Icon(Icons.check),
                  label: const Text('Apply move'),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
