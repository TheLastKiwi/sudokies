import 'package:flutter/material.dart';

import '../app.dart';
import '../data/puzzle.dart';
import '../data/puzzle_repository.dart';
import '../engine/step.dart';
import '../state/game_state.dart';
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
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter share code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '6-character code'),
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
    if (code == null || code.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final puzzle = await services.repository.byCode(code);
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
      body: SafeArea(
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
    );
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
