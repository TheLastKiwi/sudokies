/// Backtracking solver used by the offline generator: finds a solution and
/// counts solutions up to 2 (enough to verify uniqueness). Not used for hints.
library;

import 'grid.dart';

class BruteSolver {
  /// Returns the unique solution string, or null if unsolvable. Does not check
  /// uniqueness — use [countSolutions] for that.
  static String? solve(String puzzle) {
    final values = _parse(puzzle);
    final cands = _candidates(values);
    if (cands == null) return null;
    if (_search(values, cands, stopAt: 1) == 0) return null;
    return [for (final v in values) '$v'].join();
  }

  /// Counts solutions, stopping once [cap] is reached (default 2). A return of
  /// 1 means the puzzle is uniquely solvable.
  static int countSolutions(String puzzle, {int cap = 2}) {
    final values = _parse(puzzle);
    final cands = _candidates(values);
    if (cands == null) return 0;
    return _search(values, cands, stopAt: cap);
  }

  static List<int> _parse(String puzzle) {
    final cleaned = puzzle.replaceAll(RegExp(r'\s'), '');
    final values = List<int>.filled(cellCount, 0);
    for (var i = 0; i < cellCount; i++) {
      final ch = cleaned[i];
      if (ch == '.' || ch == '0') continue;
      values[i] = int.parse(ch);
    }
    return values;
  }

  /// Candidate masks for empty cells; null if a given violates the rules.
  static List<int>? _candidates(List<int> values) {
    final cands = List<int>.filled(cellCount, 0);
    for (var i = 0; i < cellCount; i++) {
      if (values[i] != 0) continue;
      var mask = allMask;
      for (final p in peers[i]) {
        if (values[p] != 0) mask &= ~maskOf(values[p]);
      }
      cands[i] = mask;
    }
    // Validate placed givens have no conflicts.
    for (var i = 0; i < cellCount; i++) {
      if (values[i] == 0) continue;
      for (final p in peers[i]) {
        if (p > i && values[p] == values[i]) return null;
      }
    }
    return cands;
  }

  /// DFS that mutates [values] in place. Returns number of solutions found, up
  /// to [stopAt]. Recomputes the affected candidate set incrementally.
  static int _search(List<int> values, List<int> cands, {required int stopAt}) {
    // Pick the empty cell with the fewest candidates (MRV heuristic).
    var target = -1;
    var best = 10;
    for (var i = 0; i < cellCount; i++) {
      if (values[i] != 0) continue;
      final n = popcount(cands[i]);
      if (n == 0) return 0; // dead end
      if (n < best) {
        best = n;
        target = i;
        if (n == 1) break;
      }
    }
    if (target == -1) return 1; // all filled => one solution

    var count = 0;
    final options = cands[target];
    for (var d = 1; d <= 9; d++) {
      if ((options & maskOf(d)) == 0) continue;
      // Apply.
      values[target] = d;
      final touched = <int>[];
      final dm = maskOf(d);
      for (final p in peers[target]) {
        if (values[p] == 0 && (cands[p] & dm) != 0) {
          cands[p] &= ~dm;
          touched.add(p);
        }
      }
      count += _search(values, cands, stopAt: stopAt - count);
      // Stop before undoing so a found solution is left intact in [values].
      if (count >= stopAt) return count;
      // Undo and try the next digit.
      values[target] = 0;
      for (final p in touched) {
        cands[p] |= dm;
      }
    }
    return count;
  }
}
