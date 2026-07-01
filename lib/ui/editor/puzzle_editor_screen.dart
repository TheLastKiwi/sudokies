import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/puzzle.dart';
import '../../engine/grid.dart';
import '../../engine/step.dart';
import '../../state/editor_state.dart';
import '../../state/game_state.dart';
import '../board_widget.dart';
import '../game_screen.dart';

/// Visual editor for authoring Killer puzzles: paint givens and cages, validate
/// (the solver derives the solution), then save/play/share.
class PuzzleEditorScreen extends StatefulWidget {
  const PuzzleEditorScreen({super.key});

  @override
  State<PuzzleEditorScreen> createState() => _PuzzleEditorScreenState();
}

class _PuzzleEditorScreenState extends State<PuzzleEditorScreen> {
  final EditorState editor = EditorState();
  final TextEditingController _sumController = TextEditingController();

  Services get services => AppScope.of(context);

  @override
  void dispose() {
    editor.dispose();
    _sumController.dispose();
    super.dispose();
  }

  GameState _gameFor(Puzzle puzzle) => GameState(
        puzzle: puzzle,
        settings: services.settings,
        history: services.history,
        library: services.library,
        prefs: services.prefs,
      );

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create puzzle'),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            onPressed: () => editor.clearAll(),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: editor,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  BoardWidget(
                    values: editor.givens,
                    candidates: List<int>.filled(cellCount, 0),
                    givens: editor.givens,
                    selectedCell: editor.selectedCell,
                    variant: editor.liveVariant,
                    roleCells: {
                      for (final c in editor.pendingCage) c: HighlightRole.base,
                    },
                    onTapCell: editor.selectCell,
                  ),
                  const SizedBox(height: 12),
                  _toolSelector(),
                  const SizedBox(height: 12),
                  if (editor.tool == EditorTool.givens)
                    _givensPanel()
                  else
                    _cagePanel(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _validateAndSave,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Validate & Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _toolSelector() {
    return SegmentedButton<EditorTool>(
      segments: const [
        ButtonSegment(
            value: EditorTool.givens,
            label: Text('Givens'),
            icon: Icon(Icons.edit)),
        ButtonSegment(
            value: EditorTool.cage,
            label: Text('Cage'),
            icon: Icon(Icons.crop_free)),
      ],
      selected: {editor.tool},
      onSelectionChanged: (s) => editor.setTool(s.first),
    );
  }

  Widget _givensPanel() {
    return Column(
      children: [
        Row(
          children: [
            for (var d = 1; d <= 9; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    onPressed: editor.selectedCell == null
                        ? null
                        : () => editor.inputGiven(d),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text('$d',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: IconButton.filledTonal(
                tooltip: 'Erase',
                onPressed:
                    editor.selectedCell == null ? null : editor.eraseGiven,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a cell, then a digit. Most Killers have few or no givens.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _cagePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap cells to group them, enter the cage sum, then Add. '
          'Tap a caged cell\'s chip to remove it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sumController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sum',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  helperText: '${editor.pendingCage.length} cell(s) selected',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addCage, child: const Text('Add cage')),
            const SizedBox(width: 4),
            TextButton(
                onPressed: editor.pendingCage.isEmpty
                    ? null
                    : editor.clearPendingCage,
                child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        if (editor.cages.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < editor.cages.length; i++)
                InputChip(
                  label: Text(
                      '${editor.cages[i].sum} (${editor.cages[i].cells.length})'),
                  onDeleted: () => editor.removeCage(i),
                ),
            ],
          ),
      ],
    );
  }

  void _addCage() {
    final sum = int.tryParse(_sumController.text.trim());
    if (sum == null) {
      _snack('Enter a numeric sum.');
      return;
    }
    final err = editor.addCage(sum);
    if (err != null) {
      _snack(err);
    } else {
      _sumController.clear();
    }
  }

  Future<void> _validateAndSave() async {
    final name = await _askName();
    if (name == null) return; // cancelled
    final puzzle = editor.buildPuzzle(name);
    if (puzzle == null) {
      _snack(editor.validationError ?? 'Could not validate the puzzle.');
      return;
    }
    await services.customPuzzles.add(puzzle);
    if (!mounted) return;
    await _savedDialog(puzzle);
  }

  Future<String?> _askName() async {
    final controller = TextEditingController(text: 'Killer');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this puzzle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Puzzle name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Validate')),
        ],
      ),
    );
  }

  Future<void> _savedDialog(Puzzle puzzle) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saved! 🎉'),
        content: Text(
          'A ${puzzle.difficulty.label} ${puzzle.variant?.name ?? 'variant'} '
          'puzzle solvable with the current techniques. It\'s in "My Puzzles".',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: puzzle.encode()));
              _snack('Share code copied to clipboard');
            },
            child: const Text('Copy share code'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => GameScreen(game: _gameFor(puzzle))),
              );
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }
}
