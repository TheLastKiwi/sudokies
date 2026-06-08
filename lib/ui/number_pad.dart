import 'package:flutter/material.dart';

import '../state/game_state.dart';

class NumberPad extends StatelessWidget {
  final GameState game;
  const NumberPad({super.key, required this.game});

  int _remaining(int digit) {
    var count = 0;
    for (final v in game.entries) {
      if (v == digit) count++;
    }
    return 9 - count;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _modeToggle(context),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var d = 1; d <= 9; d++)
              Expanded(child: _digit(context, d)),
          ],
        ),
      ],
    );
  }

  Widget _modeToggle(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<EntryMode>(
            segments: const [
              ButtonSegment(
                value: EntryMode.fill,
                label: Text('Fill'),
                icon: Icon(Icons.edit),
              ),
              ButtonSegment(
                value: EntryMode.candidate,
                label: Text('Notes'),
                icon: Icon(Icons.grid_3x3),
              ),
            ],
            selected: {game.mode},
            onSelectionChanged: (s) => game.setMode(s.first),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Erase',
          onPressed: game.erase,
          icon: const Icon(Icons.backspace_outlined),
        ),
      ],
    );
  }

  Widget _digit(BuildContext context, int d) {
    final remaining = _remaining(d);
    final exhausted = remaining <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AspectRatio(
        aspectRatio: 0.78,
        child: OutlinedButton(
          onPressed: exhausted ? null : () => game.inputDigit(d),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text('$remaining',
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ),
    );
  }
}
