import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/puzzle.dart';
import '../../engine/constraints/killer_cage.dart';
import '../../engine/constraints/pair_dot.dart';
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
  final TextEditingController _dotValueController =
      TextEditingController(text: '10');
  PairDotKind _dotKind = PairDotKind.ratio;

  Services get services => AppScope.of(context);

  @override
  void dispose() {
    editor.dispose();
    _sumController.dispose();
    _dotValueController.dispose();
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
                      for (final c in editor.pending) c: HighlightRole.base,
                    },
                    onTapCell: editor.selectCell,
                  ),
                  const SizedBox(height: 12),
                  _toolSelector(),
                  const SizedBox(height: 12),
                  _toolPanel(),
                  const SizedBox(height: 8),
                  _constraintChips(),
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

  static const _toolLabels = {
    EditorTool.givens: 'Givens',
    EditorTool.cage: 'Cage',
    EditorTool.thermo: 'Thermo',
    EditorTool.arrow: 'Arrow',
    EditorTool.dot: 'Dot',
  };

  Widget _toolSelector() {
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final t in EditorTool.values)
          ChoiceChip(
            label: Text(_toolLabels[t]!),
            selected: editor.tool == t,
            onSelected: (_) => editor.setTool(t),
          ),
      ],
    );
  }

  Widget _toolPanel() {
    switch (editor.tool) {
      case EditorTool.givens:
        return _givensPanel();
      case EditorTool.cage:
        return _cagePanel();
      case EditorTool.thermo:
        return _pathPanel(
          hint: 'Tap cells from the bulb (lowest) to the tip (highest). '
              'Digits strictly increase.',
          addLabel: 'Add thermometer',
          onAdd: () => editor.addThermo(),
        );
      case EditorTool.arrow:
        return _pathPanel(
          hint: 'Tap the bulb first, then the path cells. The path sums to the '
              'bulb.',
          addLabel: 'Add arrow',
          onAdd: () => editor.addArrow(),
        );
      case EditorTool.dot:
        return _dotPanel();
    }
  }

  Widget _dotPanel() {
    final needsValue = _dotKind != PairDotKind.consecutive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap two adjacent cells, choose the relation, then Add. '
          'Ratio = one is N× the other; Sum uses X=10, V=5.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final k in PairDotKind.values)
              ChoiceChip(
                label: Text(_dotKindLabel(k)),
                selected: _dotKind == k,
                onSelected: (_) => setState(() => _dotKind = k),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (needsValue)
              Expanded(
                child: TextField(
                  controller: _dotValueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _dotKind == PairDotKind.ratio ? 'Factor' : 'Sum',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    helperText: '${editor.pending.length}/2 cells selected',
                  ),
                ),
              )
            else
              Expanded(
                child: Text('${editor.pending.length}/2 cells selected',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addDot, child: const Text('Add dot')),
            const SizedBox(width: 4),
            TextButton(
                onPressed: editor.pending.isEmpty ? null : editor.clearPending,
                child: const Text('Clear')),
          ],
        ),
      ],
    );
  }

  String _dotKindLabel(PairDotKind k) {
    switch (k) {
      case PairDotKind.ratio:
        return 'Ratio';
      case PairDotKind.consecutive:
        return 'Consecutive';
      case PairDotKind.sum:
        return 'Sum';
    }
  }

  void _addDot() {
    final value = _dotKind == PairDotKind.consecutive
        ? 0
        : (int.tryParse(_dotValueController.text.trim()) ?? -1);
    final err = editor.addDot(_dotKind, value);
    if (err != null) _snack(err);
  }

  Widget _pathPanel({
    required String hint,
    required String addLabel,
    required String? Function() onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('${editor.pending.length} cell(s) selected'),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final err = onAdd();
                if (err != null) _snack(err);
              },
              child: Text(addLabel),
            ),
            const SizedBox(width: 4),
            TextButton(
                onPressed: editor.pending.isEmpty ? null : editor.clearPending,
                child: const Text('Clear')),
          ],
        ),
      ],
    );
  }

  Widget _constraintChips() {
    if (editor.constraints.isEmpty) return const SizedBox.shrink();
    String label(int i) {
      final c = editor.constraints[i];
      if (c is KillerCage) return 'Cage ${c.sum} (${c.cells.length})';
      if (c is PairDot) {
        switch (c.kind) {
          case PairDotKind.ratio:
            return 'Ratio ${c.value == 0 ? 2 : c.value}:1';
          case PairDotKind.consecutive:
            return 'Consecutive';
          case PairDotKind.sum:
            return 'Sum ${c.value}';
        }
      }
      switch (c.type) {
        case 'thermometer':
          return 'Thermo (${c.cells.length})';
        case 'arrow':
          return 'Arrow (${c.cells.length})';
        default:
          return c.type;
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < editor.constraints.length; i++)
          InputChip(
            label: Text(label(i)),
            onDeleted: () => editor.removeConstraint(i),
          ),
      ],
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
          'Tap cells to group them, enter the cage sum, then Add.',
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
                  helperText: '${editor.pending.length} cell(s) selected',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addCage, child: const Text('Add cage')),
            const SizedBox(width: 4),
            TextButton(
                onPressed:
                    editor.pending.isEmpty ? null : editor.clearPending,
                child: const Text('Clear')),
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
