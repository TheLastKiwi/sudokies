/// Core Sudoku board representation, bitmask candidate helpers, and the
/// precomputed peer/unit tables shared by the solver, strategies and hints.
///
/// Cell index convention: `index = row * 9 + col`, rows/cols/boxes are 0-based.
/// Candidates for a cell are stored as a 9-bit mask where bit `d-1` set means
/// digit `d` (1..9) is still possible. `allMask` (0x1FF) means all nine digits.
library;

const int cellCount = 81;
const int allMask = 0x1FF; // 511, bits for digits 1..9

int rowOf(int i) => i ~/ 9;
int colOf(int i) => i % 9;
int boxOf(int i) => (rowOf(i) ~/ 3) * 3 + (colOf(i) ~/ 3);

/// Bit mask for a single digit (1..9).
int maskOf(int digit) => 1 << (digit - 1);

bool maskHas(int mask, int digit) => (mask & maskOf(digit)) != 0;

int popcount(int mask) {
  var n = 0;
  while (mask != 0) {
    mask &= mask - 1;
    n++;
  }
  return n;
}

/// Digits (1..9) present in [mask], ascending.
List<int> digitsOf(int mask) {
  final out = <int>[];
  for (var d = 1; d <= 9; d++) {
    if ((mask & maskOf(d)) != 0) out.add(d);
  }
  return out;
}

/// If [mask] has exactly one bit, the digit; otherwise 0.
int singleDigit(int mask) {
  if (mask != 0 && (mask & (mask - 1)) == 0) {
    for (var d = 1; d <= 9; d++) {
      if (mask == maskOf(d)) return d;
    }
  }
  return 0;
}

// ---- Precomputed structure -------------------------------------------------

/// The 27 units: 9 rows, then 9 columns, then 9 boxes. Each is 9 cell indices.
final List<List<int>> units = _buildUnits();

/// For each cell, the 20 peer cells (same row/col/box, excluding itself).
final List<List<int>> peers = _buildPeers();

/// For each cell, the indices into [units] of its row, col and box units.
final List<List<int>> unitsOfCell = _buildUnitsOfCell();

List<List<int>> _buildUnits() {
  final u = <List<int>>[];
  // Rows
  for (var r = 0; r < 9; r++) {
    u.add([for (var c = 0; c < 9; c++) r * 9 + c]);
  }
  // Columns
  for (var c = 0; c < 9; c++) {
    u.add([for (var r = 0; r < 9; r++) r * 9 + c]);
  }
  // Boxes
  for (var br = 0; br < 3; br++) {
    for (var bc = 0; bc < 3; bc++) {
      final cells = <int>[];
      for (var dr = 0; dr < 3; dr++) {
        for (var dc = 0; dc < 3; dc++) {
          cells.add((br * 3 + dr) * 9 + (bc * 3 + dc));
        }
      }
      u.add(cells);
    }
  }
  return u;
}

List<List<int>> _buildPeers() {
  final result = List.generate(cellCount, (_) => <int>{});
  for (final unit in _buildUnits()) {
    for (final a in unit) {
      for (final b in unit) {
        if (a != b) result[a].add(b);
      }
    }
  }
  return [for (final s in result) s.toList()..sort()];
}

List<List<int>> _buildUnitsOfCell() {
  final allUnits = _buildUnits();
  final result = List.generate(cellCount, (_) => <int>[]);
  for (var ui = 0; ui < allUnits.length; ui++) {
    for (final cell in allUnits[ui]) {
      result[cell].add(ui);
    }
  }
  return result;
}

/// Row units are indices 0..8, columns 9..17, boxes 18..26.
const int rowUnitBase = 0;
const int colUnitBase = 9;
const int boxUnitBase = 18;

String unitName(int unitIndex) {
  if (unitIndex < colUnitBase) return 'row ${unitIndex - rowUnitBase + 1}';
  if (unitIndex < boxUnitBase) return 'column ${unitIndex - colUnitBase + 1}';
  return 'box ${unitIndex - boxUnitBase + 1}';
}

String cellName(int i) => 'r${rowOf(i) + 1}c${colOf(i) + 1}';

/// A mutable solving state: fixed/placed values plus candidate masks.
///
/// `values[i] == 0` means the cell is empty and `cands[i]` holds its candidate
/// mask. When a value is placed, `cands[i]` is cleared to 0.
class CandidateGrid {
  final List<int> values;
  final List<int> cands;

  CandidateGrid._(this.values, this.cands);

  /// Build from an 81-char puzzle string. Blanks may be '.', '0' or ' '.
  factory CandidateGrid.fromString(String puzzle) {
    final values = List<int>.filled(cellCount, 0);
    final cleaned = puzzle.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length != cellCount) {
      throw ArgumentError('Puzzle must be 81 cells, got ${cleaned.length}');
    }
    for (var i = 0; i < cellCount; i++) {
      final ch = cleaned[i];
      if (ch == '.' || ch == '0') continue;
      final d = int.tryParse(ch);
      if (d == null || d < 1 || d > 9) {
        throw ArgumentError('Invalid cell "$ch" at $i');
      }
      values[i] = d;
    }
    final grid = CandidateGrid._(values, List<int>.filled(cellCount, 0));
    grid.recomputeBasicCandidates();
    return grid;
  }

  /// Build from explicit values and player-supplied candidate masks (a copy).
  factory CandidateGrid.fromState(List<int> values, List<int> cands) {
    return CandidateGrid._(List<int>.from(values), List<int>.from(cands));
  }

  /// Build from placed values only, deriving basic (row/col/box) candidates.
  factory CandidateGrid.fromValues(List<int> values) {
    final g = CandidateGrid._(
      List<int>.from(values),
      List<int>.filled(cellCount, 0),
    );
    g.recomputeBasicCandidates();
    return g;
  }

  CandidateGrid clone() => CandidateGrid._(
        List<int>.from(values),
        List<int>.from(cands),
      );

  /// Reset every empty cell's candidates to the basic set implied by peers'
  /// placed values (row/col/box elimination only).
  void recomputeBasicCandidates() {
    for (var i = 0; i < cellCount; i++) {
      if (values[i] != 0) {
        cands[i] = 0;
        continue;
      }
      var mask = allMask;
      for (final p in peers[i]) {
        if (values[p] != 0) mask &= ~maskOf(values[p]);
      }
      cands[i] = mask;
    }
  }

  bool get isSolved => !values.contains(0);

  /// Place [digit] in [cell], clearing peers' candidate for that digit.
  void place(int cell, int digit) {
    values[cell] = digit;
    cands[cell] = 0;
    for (final p in peers[cell]) {
      cands[p] &= ~maskOf(digit);
    }
  }

  /// Remove [digit] as a candidate of [cell]. Returns true if it was present.
  bool eliminate(int cell, int digit) {
    final before = cands[cell];
    cands[cell] &= ~maskOf(digit);
    return cands[cell] != before;
  }

  /// Cells of [unit] (by index into [units]) that still hold [digit].
  List<int> cellsWithCandidateInUnit(int unitIndex, int digit) {
    final m = maskOf(digit);
    return [
      for (final c in units[unitIndex])
        if (values[c] == 0 && (cands[c] & m) != 0) c
    ];
  }

  String toBoardString() =>
      [for (final v in values) v == 0 ? '.' : '$v'].join();
}
