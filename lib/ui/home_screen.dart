import 'package:flutter/material.dart';

import '../app.dart';
import '../data/puzzle.dart';
import '../data/puzzle_repository.dart';
import '../engine/step.dart';
import '../state/game_state.dart';
import 'editor/puzzle_editor_screen.dart';
import 'game_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'techniques_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Services get services => AppScope.of(context);

  GameState _gameFor(Puzzle puzzle) => GameState(
        puzzle: puzzle,
        settings: services.settings,
        history: services.history,
        library: services.library,
        prefs: services.prefs,
      );

  Future<void> _open(GameState game) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(game: game)),
    );
    if (mounted) setState(() {}); // refresh Continue card after returning
  }

  Future<void> _newGame(Difficulty difficulty) async {
    setState(() => _loading = true);
    try {
      final puzzle = await services.repository.randomByDifficulty(difficulty);
      if (!mounted) return;
      await _open(_gameFor(puzzle));
    } on PuzzleNotFound catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not load a puzzle. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDifficulty() async {
    final choice = await showModalBottomSheet<Difficulty>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose difficulty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final d in Difficulty.values)
              ListTile(
                title: Text(d.label),
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (choice != null) _newGame(choice);
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter code or share string'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: '6-character code or shared puzzle'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Load')),
        ],
      ),
    );
    final text = input?.trim() ?? '';
    if (text.isEmpty) return;

    // A pasted variant puzzle is self-contained — decode it directly rather
    // than looking it up in the code-based bank.
    if (text.startsWith('SUDOKIES1:')) {
      try {
        final puzzle = Puzzle.decode(text);
        if (!mounted) return;
        await _open(_gameFor(puzzle));
      } catch (_) {
        _showError('That shared puzzle could not be read.');
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final puzzle = await services.repository.byCode(text.toUpperCase());
      if (!mounted) return;
      await _open(_gameFor(puzzle));
    } on PuzzleNotFound catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not load that code. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPuzzle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PuzzleEditorScreen()),
    );
    if (mounted) setState(() {}); // refresh My Puzzles after returning
  }

  void _continue() {
    final game = restoreSavedGame(
      prefs: services.prefs,
      settings: services.settings,
      history: services.history,
      library: services.library,
    );
    if (game == null) {
      _showError('No saved game to continue.');
      return;
    }
    _open(game);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final saved = savedGamePuzzle(services.prefs);
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 24),
                Text('Sudokies',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Learn the techniques as you play.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                if (saved != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: const Text('Continue'),
                      subtitle: Text(
                          '${saved.difficulty.label} puzzle ${saved.code}'),
                      onTap: _loading ? null : _continue,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : _pickDifficulty,
                  icon: const Icon(Icons.add),
                  label: const Text('New Game'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _enterCode,
                  icon: const Icon(Icons.tag),
                  label: const Text('Enter Code'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _createPuzzle,
                  icon: const Icon(Icons.brush_outlined),
                  label: const Text('Create Puzzle'),
                ),
                ..._myPuzzles(),
                const SizedBox(height: 24),
                _navTile(Icons.school, 'Techniques',
                    () => _push(const TechniquesScreen())),
                _navTile(Icons.history, 'History',
                    () => _push(const HistoryScreen())),
                _navTile(Icons.settings, 'Settings',
                    () => _push(const SettingsScreen())),
                if (_loading) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: SafeArea(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    appVersion,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _myPuzzles() {
    final puzzles = services.customPuzzles.puzzles;
    if (puzzles.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('My Puzzles',
            style: Theme.of(context).textTheme.titleSmall),
      ),
      const SizedBox(height: 4),
      for (final p in puzzles)
        Card(
          child: ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: Text(p.variant?.name ?? 'Custom puzzle'),
            subtitle: Text('${p.difficulty.label} · ${p.code}'),
            onTap: _loading ? null : () => _open(_gameFor(p)),
            trailing: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await services.customPuzzles.remove(p.code);
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
    ];
  }

  Widget _navTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }
}
