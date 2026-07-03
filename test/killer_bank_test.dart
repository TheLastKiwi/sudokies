import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/data/puzzle_repository.dart';
import 'package:sudokies/engine/step.dart';

/// Guards the Killer New Game picker: every difficulty the picker shows comes
/// from [PuzzleRepository.killerTiers], so each of those tiers must actually
/// yield a Killer puzzle. Tiers with no puzzles must not be shown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('killerTiers lists exactly the tiers that have bundled puzzles', () async {
    final repo = PuzzleRepository();
    final tiers = await repo.killerTiers();
    expect(
      tiers,
      [Difficulty.easy, Difficulty.medium, Difficulty.hard, Difficulty.expert],
    );
    // Extreme has no bundled Killer puzzles, so the picker must omit it.
    expect(tiers, isNot(contains(Difficulty.extreme)));
  });

  test('every shown tier yields a real Killer puzzle', () async {
    final repo = PuzzleRepository();
    for (final tier in await repo.killerTiers()) {
      final puzzle = await repo.randomKillerByDifficulty(tier);
      expect(puzzle.difficulty, tier, reason: '$tier puzzle mislabelled');
      expect(puzzle.isVariant, isTrue, reason: '$tier puzzle has no cages');
      expect(puzzle.variant!.type, 'killer', reason: '$tier not a Killer puzzle');
    }
  });

  test('an unavailable tier throws instead of returning a bad puzzle', () async {
    final repo = PuzzleRepository();
    expect(
      () => repo.randomKillerByDifficulty(Difficulty.extreme),
      throwsA(isA<PuzzleNotFound>()),
    );
  });
}
