import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudokies/data/custom_puzzle_store.dart';
import 'package:sudokies/data/puzzle.dart';
import 'package:sudokies/data/variant_spec.dart';
import 'package:sudokies/engine/brute_solver.dart';
import 'package:sudokies/engine/constraints/arrow.dart';
import 'package:sudokies/engine/constraints/killer_cage.dart';
import 'package:sudokies/engine/step.dart';
import 'package:sudokies/state/editor_state.dart';

void main() {
  const easy =
      '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

  void setGivens(EditorState e, String board) {
    for (var i = 0; i < 81; i++) {
      final ch = board[i];
      e.givens[i] = (ch == '.' || ch == '0') ? 0 : int.parse(ch);
    }
  }

  group('EditorState.addCage', () {
    test('rejects fewer than two cells', () {
      final e = EditorState();
      e.pending.add(0);
      expect(e.addCage(5), isNotNull);
      expect(e.cages, isEmpty);
    });

    test('rejects an unreachable sum', () {
      final e = EditorState();
      e.pending.addAll([0, 1]); // two cells: min 3, max 17
      expect(e.addCage(2), isNotNull);
      expect(e.addCage(18), isNotNull);
      expect(e.cages, isEmpty);
    });

    test('commits a valid cage and clears the pending selection', () {
      final e = EditorState();
      e.pending.addAll([0, 1, 2]);
      expect(e.addCage(12), isNull);
      expect(e.cages, hasLength(1));
      expect(e.cages.single.cells, [0, 1, 2]);
      expect(e.cages.single.sum, 12);
      expect(e.pending, isEmpty);
    });
  });

  group('EditorState line tools', () {
    test('addThermo commits an ordered path', () {
      final e = EditorState();
      e.setTool(EditorTool.thermo);
      e.pending.addAll([0, 30, 60]);
      expect(e.addThermo(), isNull);
      expect(e.constraints, hasLength(1));
      expect(e.constraints.single.type, 'thermometer');
    });

    test('addArrow uses the first cell as the bulb', () {
      final e = EditorState();
      e.setTool(EditorTool.arrow);
      e.pending.addAll([0, 30, 60]);
      expect(e.addArrow(), isNull);
      final arrow = e.constraints.single as Arrow;
      expect(arrow.bulb, [0]);
      expect(arrow.path, [30, 60]);
    });

    test('line tools reject a single cell', () {
      final e = EditorState();
      e.pending.add(0);
      expect(e.addThermo(), isNotNull);
      expect(e.addArrow(), isNotNull);
      expect(e.constraints, isEmpty);
    });
  });

  group('EditorState.buildPuzzle', () {
    test('derives the solution for a solvable design', () {
      final e = EditorState();
      setGivens(e, easy);
      e.pending.addAll([0, 1, 2]);
      e.addCage(12); // 5+3+4 in the solution
      final puzzle = e.buildPuzzle('My Killer');
      expect(puzzle, isNotNull);
      expect(puzzle!.solution, BruteSolver.solve(easy));
      expect(puzzle.variant?.name, 'My Killer');
      expect(puzzle.variant?.constraints.whereType<KillerCage>(), hasLength(1));
    });

    test('fails and explains when the design is unsolvable', () {
      final e = EditorState();
      // No givens, one loose cage — not solvable by the techniques.
      e.pending.addAll([0, 1]);
      e.addCage(5);
      final puzzle = e.buildPuzzle('Nope');
      expect(puzzle, isNull);
      expect(e.validationError, isNotNull);
    });
  });

  group('CustomPuzzleStore', () {
    test('persists and reloads saved puzzles', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = CustomPuzzleStore(prefs);
      const puzzle = Puzzle(
        code: 'MYKILL',
        board: '.',
        solution: '1',
        difficulty: Difficulty.medium,
        variant: VariantSpec(
          name: 'Killer',
          type: 'killer',
          constraints: [KillerCage([0, 1, 2], 12)],
        ),
      );
      await store.add(puzzle);

      final reloaded = CustomPuzzleStore(prefs);
      expect(reloaded.puzzles, hasLength(1));
      expect(reloaded.puzzles.first.code, 'MYKILL');
      expect(reloaded.puzzles.first.variant?.constraints, hasLength(1));

      await reloaded.remove('MYKILL');
      expect(CustomPuzzleStore(prefs).puzzles, isEmpty);
    });
  });
}
