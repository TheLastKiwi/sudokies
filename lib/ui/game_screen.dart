import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/step.dart';
import '../state/game_state.dart';
import '../state/settings.dart';
import 'board_widget.dart';
import 'controls_bar.dart';
import 'hint_panel.dart';
import 'number_pad.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState game;
  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _timer;
  bool _winShown = false;

  GameState get game => widget.game;
  Settings get settings => game.settings;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => game.tickSecond());
  }

  @override
  void dispose() {
    _timer?.cancel();
    game.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Set<int> _wrongCells() {
    if (!settings.flagMistakes) return game.wrongCells;
    final live = <int>{...game.wrongCells};
    for (var i = 0; i < game.entries.length; i++) {
      if (!game.givenAt(i) &&
          game.entries[i] != 0 &&
          game.entries[i] != game.solutionValues[i]) {
        live.add(i);
      }
    }
    return live;
  }

  void _maybeShowWin() {
    if (game.solved && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  Future<void> _showWinDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solved! 🎉'),
        content: Text(
          '${game.puzzle.difficulty.label} puzzle ${game.puzzle.code}\n'
          'Time: ${_fmt(game.elapsedSeconds)}\n'
          'Hints used: ${game.hintsUsed}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to home
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([game, settings]),
          builder: (context, _) {
            _maybeShowWin();
            final hintActive = game.hintView != null;
            return Stack(
              children: [
                // Hide the live board while a hint overlay is up so two full
                // boards never paint at once — iOS WebKit's canvas/memory cap
                // crashes the tab when both render simultaneously. Offstage
                // keeps scroll/selection state without laying out or painting.
                Offstage(
                  offstage: hintActive,
                  child: Column(
                    children: [
                      _topBar(context),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              BoardWidget(
                                values: game.entries,
                                candidates: game.candidates,
                                givens: game.givens,
                                selectedCell: game.selectedCell,
                                highlightDigit:
                                    game.autoEntry ? game.penDigit : null,
                                wrongCells: _wrongCells(),
                                hideContent: game.paused,
                                onTapCell: game.selectCell,
                              ),
                              const SizedBox(height: 16),
                              ControlsBar(game: game),
                              const SizedBox(height: 12),
                              NumberPad(game: game),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (game.paused) _pausedOverlay(context),
                if (hintActive) HintPanel(game: game),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.puzzle.difficulty.label,
                  style: Theme.of(context).textTheme.titleMedium),
              InkWell(
                onTap: _copyCode,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(game.puzzle.code,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (settings.showTimer) ...[
            Text(_fmt(game.elapsedSeconds),
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              onPressed: game.togglePause,
              icon: Icon(game.paused ? Icons.play_arrow : Icons.pause),
            ),
          ],
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  Widget _pausedOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.center,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paused', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: game.togglePause,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: game.puzzle.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied code ${game.puzzle.code}')),
    );
  }
}
