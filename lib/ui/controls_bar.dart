import 'package:flutter/material.dart';

import '../state/game_state.dart';

class ControlsBar extends StatelessWidget {
  final GameState game;
  const ControlsBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        _btn(Icons.undo, 'Undo', game.canUndo ? game.undo : null),
        _btn(Icons.redo, 'Redo', game.canRedo ? game.redo : null),
        _btn(Icons.edit_note, 'Notes fill', game.toggleNotesFill,
            active: game.notesFillActive),
        _btn(Icons.lightbulb_outline, 'Hint', game.requestHint),
        _btn(Icons.checklist, 'Check', () => _check(context)),
        _btn(Icons.restart_alt, 'Reset', () => _confirmReset(context)),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onTap,
      {bool active = false}) {
    final button = active
        ? IconButton.filled(onPressed: onTap, icon: Icon(icon))
        : IconButton.filledTonal(onPressed: onTap, icon: Icon(icon));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _check(BuildContext context) {
    final wrong = game.check();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          wrong == 0
              ? 'No mistakes found.'
              : '$wrong incorrect ${wrong == 1 ? 'cell' : 'cells'} highlighted.',
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset puzzle?'),
        content: const Text(
            'This clears all your entries and notes back to the original puzzle.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) game.reset();
  }
}
