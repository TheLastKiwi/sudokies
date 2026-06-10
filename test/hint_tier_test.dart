import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudokies/data/history_store.dart';
import 'package:sudokies/data/puzzle.dart';
import 'package:sudokies/data/technique_library.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/state/game_state.dart';
import 'package:sudokies/state/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameState> loadGame() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    final history = HistoryStore(prefs);
    final library = await TechniqueLibrary.load();
    final raw = await rootBundle.loadString('assets/puzzles/starter.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = json['puzzles'] as Map<String, dynamic>;
    final first = (puzzles.values.first as List).first;
    final puz = Puzzle.fromJson(Map<String, dynamic>.from(first as Map));
    return GameState(
      puzzle: puz,
      settings: settings,
      history: history,
      library: library,
      prefs: prefs,
    );
  }

  test('empty notes ask for more notes, not a strategy', () async {
    final game = await loadGame();
    game.requestHint();
    expect(game.hintView, isNotNull);
    expect(game.hintView!.strategyName, 'Add more notes');
  });

  test('full notes never trigger the easier-move nudge', () async {
    final game = await loadGame();
    game.toggleNotesFill(); // _auto = full basic candidates
    game.requestHint();
    expect(game.hintView, isNotNull);
    // With complete notes the cheapest visible move is at or below the
    // puzzle's rated difficulty, so we should teach it, not nudge.
    expect(game.hintView!.strategyName, isNot('Easier move available'));
  });

  test('notes that lack the solution candidate ask for required candidates',
      () async {
    final game = await loadGame();
    // Put a single note on an empty cell using a digit a peer already holds, so
    // basic elimination wipes it out: the board exposes no technique, yet the
    // player has a note that doesn't include the cell's true solution digit.
    int? cell;
    int? digit;
    for (var i = 0; i < cellCount && cell == null; i++) {
      if (game.entries[i] != 0) continue;
      for (final p in peers[i]) {
        final d = game.entries[p];
        if (d != 0 && d != game.solutionValues[i]) {
          cell = i;
          digit = d;
          break;
        }
      }
    }
    expect(cell, isNotNull, reason: 'expected an empty cell with a peer given');

    game.selectCell(cell!);
    game.setMode(EntryMode.candidate);
    game.inputDigit(digit!);
    game.requestHint();

    expect(game.hintView, isNotNull);
    expect(game.hintView!.strategyName, 'Missing required candidates');
  });
}
