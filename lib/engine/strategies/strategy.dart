/// Registry of solving techniques, ordered easiest-first. The logical solver
/// and grader walk this list; the hint engine and techniques screen also use
/// the metadata (name/description) here.
library;

import '../grid.dart';
import '../step.dart';
import 'singles.dart';
import 'locked_candidates.dart';
import 'subsets.dart';
import 'fish.dart';
import 'wings.dart';
import 'colouring.dart';
import 'unique_rectangle.dart';
import 'killer.dart';

typedef ApplyFn = SolveStep? Function(CandidateGrid grid);

class Strategy {
  final String id;
  final String name;
  final int rank;
  final String description;
  final ApplyFn apply;

  const Strategy({
    required this.id,
    required this.name,
    required this.rank,
    required this.description,
    required this.apply,
  });

  Difficulty get tier => tierForRank(rank);
}

/// All techniques, sorted by increasing difficulty rank.
final List<Strategy> allStrategies = [
  // ---- Easy ----
  Strategy(
    id: 'full_house',
    name: 'Full House',
    rank: 0,
    description:
        'A unit (row, column or box) with only one empty cell. That cell '
        'must hold the one digit missing from the unit.',
    apply: fullHouse,
  ),
  Strategy(
    id: 'naked_single',
    name: 'Naked Single',
    rank: 1,
    description:
        'A cell with only one remaining candidate. No other digit can go '
        'there, so place it.',
    apply: nakedSingle,
  ),
  Strategy(
    id: 'hidden_single',
    name: 'Hidden Single',
    rank: 5,
    description:
        'Within a unit, a digit can only go in one cell even though that '
        'cell has other candidates. Place the digit there.',
    apply: hiddenSingle,
  ),
  // ---- Medium ----
  Strategy(
    id: 'pointing',
    name: 'Pointing Pair/Triple',
    rank: 11,
    description:
        'In a box, all candidates for a digit lie on a single row or column. '
        'That digit can be removed from the rest of that row or column.',
    apply: pointing,
  ),
  Strategy(
    id: 'claiming',
    name: 'Claiming (Box-Line)',
    rank: 12,
    description:
        'In a row or column, all candidates for a digit lie within one box. '
        'That digit can be removed from the rest of that box.',
    apply: claiming,
  ),
  Strategy(
    id: 'naked_pair',
    name: 'Naked Pair',
    rank: 13,
    description:
        'Two cells in a unit share the same two candidates. Those two digits '
        'can be removed from every other cell in the unit.',
    apply: nakedPair,
  ),
  Strategy(
    id: 'hidden_pair',
    name: 'Hidden Pair',
    rank: 14,
    description:
        'Two digits can only go in the same two cells of a unit. All other '
        'candidates can be removed from those two cells.',
    apply: hiddenPair,
  ),
  // ---- Hard ----
  Strategy(
    id: 'naked_triple',
    name: 'Naked Triple',
    rank: 21,
    description:
        'Three cells in a unit together hold only three candidates. Those '
        'three digits can be removed from the rest of the unit.',
    apply: nakedTriple,
  ),
  Strategy(
    id: 'hidden_triple',
    name: 'Hidden Triple',
    rank: 22,
    description:
        'Three digits are confined to the same three cells of a unit. Other '
        'candidates can be removed from those cells.',
    apply: hiddenTriple,
  ),
  Strategy(
    id: 'naked_quad',
    name: 'Naked Quad',
    rank: 25,
    description:
        'Four cells in a unit together hold only four candidates. Those four '
        'digits can be removed from the rest of the unit.',
    apply: nakedQuad,
  ),
  Strategy(
    id: 'x_wing',
    name: 'X-Wing',
    rank: 26,
    description:
        'A digit forms a rectangle: in two rows it appears in only the same '
        'two columns (or vice versa). It can be removed from those columns '
        'elsewhere.',
    apply: xWing,
  ),
  // ---- Expert ----
  Strategy(
    id: 'swordfish',
    name: 'Swordfish',
    rank: 31,
    description:
        'A 3x3 generalisation of the X-Wing: a digit confined to three '
        'columns across three rows lets you eliminate it elsewhere in those '
        'columns.',
    apply: swordfish,
  ),
  Strategy(
    id: 'xy_wing',
    name: 'XY-Wing',
    rank: 32,
    description:
        'A pivot cell XY sees two cells XZ and YZ. Whichever digit the pivot '
        'takes, one wing becomes Z, so Z is removed from cells seeing both '
        'wings.',
    apply: xyWing,
  ),
  Strategy(
    id: 'simple_colouring',
    name: 'Simple Colouring',
    rank: 33,
    description:
        'Chain the two cells of each conjugate pair for a digit with '
        'alternating colours. A cell seeing both colours cannot hold the '
        'digit.',
    apply: simpleColouring,
  ),
  // ---- Extreme ----
  Strategy(
    id: 'unique_rectangle',
    name: 'Unique Rectangle (Type 1)',
    rank: 40,
    description:
        'Four cells forming a rectangle across two boxes sharing the same two '
        'candidates would give two solutions. Removing the extra-candidate '
        'cell\'s pair digits avoids the deadly pattern.',
    apply: uniqueRectangleType1,
  ),
  Strategy(
    id: 'xyz_wing',
    name: 'XYZ-Wing',
    rank: 41,
    description:
        'Like an XY-Wing but the pivot also contains Z. Cells seeing all '
        'three of the pivot and both wings cannot hold Z.',
    apply: xyzWing,
  ),
  Strategy(
    id: 'jellyfish',
    name: 'Jellyfish',
    rank: 42,
    description:
        'A 4x4 fish: a digit confined to four columns across four rows lets '
        'you eliminate it elsewhere in those columns.',
    apply: jellyfish,
  ),
  // ---- Variant: Killer Sudoku ----
  // These short-circuit on classic (constraint-free) grids, so they add no
  // behaviour there; they only fire when a puzzle carries killer cages.
  Strategy(
    id: 'killer_last_cell',
    name: 'Cage Last Cell',
    rank: 3,
    description:
        'A killer cage with one empty cell must hold the digit that makes the '
        'cage reach its target sum.',
    apply: killerLastCell,
  ),
  Strategy(
    id: 'killer_no_repeat',
    name: 'Cage No-Repeat',
    rank: 6,
    description:
        'A killer cage never repeats a digit, so a digit already placed in the '
        'cage can be removed from its other cells.',
    apply: killerNoRepeat,
  ),
  Strategy(
    id: 'killer_cage_sums',
    name: 'Cage Sum Combinations',
    rank: 15,
    description:
        'The empty cells of a killer cage must form a distinct-digit '
        'combination summing to the remaining total. Digits in no valid '
        'combination can be removed.',
    apply: killerCageSums,
  ),
]..sort((a, b) => a.rank.compareTo(b.rank));

Strategy? strategyById(String id) {
  for (final s in allStrategies) {
    if (s.id == id) return s;
  }
  return null;
}
