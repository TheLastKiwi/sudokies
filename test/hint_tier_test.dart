import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudokies/data/history_store.dart';
import 'package:sudokies/data/puzzle.dart';
import 'package:sudokies/data/technique_library.dart';
import 'package:sudokies/engine/grid.dart';
import 'package:sudokies/engine/hint.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/state/game_state.dart';
import 'package:sudokies/state/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameState> loadGame({String difficulty = 'easy'}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    final history = HistoryStore(prefs);
    final library = await TechniqueLibrary.load();
    final raw = await rootBundle.loadString('assets/puzzles/starter.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = json['puzzles'] as Map<String, dynamic>;
    final first = (puzzles[difficulty] as List).first;
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

  test('a wrong entry blocks hints and is reported', () async {
    final game = await loadGame();
    game.toggleNotesFill(); // full valid notes: a technique would be visible
    final cell =
        List.generate(cellCount, (i) => i).firstWhere((i) => game.entries[i] == 0);
    final wrong = game.solutionValues[cell] == 9 ? 1 : 9;
    game.selectCell(cell);
    game.setMode(EntryMode.fill);
    game.inputDigit(wrong);
    game.requestHint();
    expect(game.hintView, isNotNull);
    expect(game.hintView!.strategyName, 'Incorrect entry');
    expect(game.hintView!.canApply, isFalse);
  });

  test('a noted cell missing its solution digit blocks an otherwise visible hint',
      () async {
    final game = await loadGame();
    game.toggleNotesFill(); // full valid notes: a technique would be visible
    final cell =
        List.generate(cellCount, (i) => i).firstWhere((i) => game.entries[i] == 0);
    game.selectCell(cell);
    game.setMode(EntryMode.candidate);
    game.inputDigit(game.solutionValues[cell]); // toggle the true digit off
    game.requestHint();
    expect(game.hintView, isNotNull);
    expect(game.hintView!.strategyName, 'Missing required candidates');
  });

  test('partially noted boards ask for more notes before hinting', () async {
    final game = await loadGame();
    // Note a single cell correctly (its solution digit); the rest stay empty.
    final cell =
        List.generate(cellCount, (i) => i).firstWhere((i) => game.entries[i] == 0);
    game.selectCell(cell);
    game.setMode(EntryMode.candidate);
    game.inputDigit(game.solutionValues[cell]);
    game.requestHint();
    expect(game.hintView, isNotNull);
    expect(game.hintView!.strategyName, 'Add more notes');
  });

  test('noteRemovalHint finds a within-tier elimination of existing notes',
      () async {
    final game = await loadGame(difficulty: 'medium');
    // A medium rating means the solve line contains a medium technique, and
    // all medium techniques are eliminations — so with full basic notes the
    // replay must find an elimination of the player's notes within tier.
    final notes = CandidateGrid.fromValues(game.entries).cands;
    final step = noteRemovalHint(game.entries, notes, Difficulty.medium);
    expect(step, isNotNull);
    expect(step!.eliminations, isNotEmpty);
    expect(tierForRank(step.difficultyRank).index,
        lessThanOrEqualTo(Difficulty.medium.index));
    expect(
      step.eliminations.any((e) => maskHas(notes[e.cell], e.digit)),
      isTrue,
    );
  });

  test('noteRemovalHint returns null when no notes can be removed', () async {
    final game = await loadGame();
    final empty = List<int>.filled(cellCount, 0);
    expect(noteRemovalHint(game.entries, empty, Difficulty.extreme), isNull);
  });
}
