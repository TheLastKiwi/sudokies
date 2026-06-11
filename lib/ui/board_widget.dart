import 'package:flutter/material.dart';

import '../engine/grid.dart';
import '../engine/step.dart';
import 'theme.dart';

/// Renders a 9x9 board. Used for live play (interactive, selection-based
/// highlighting) and for hint/example display (explicit role highlights).
class BoardWidget extends StatelessWidget {
  final List<int> values;
  final List<int> candidates; // masks
  final List<int> givens; // 0 where not a given
  final int? selectedCell;

  /// A digit to highlight across the board even when no filled cell is
  /// selected — used by auto-entry's "pen" so picking a number lights up every
  /// cell holding it, exactly as selecting a filled cell of that digit does.
  final int? highlightDigit;
  final Set<int> wrongCells;
  final Map<int, HighlightRole> roleCells;
  final List<CandidateMark> roleCandidates;
  final bool interactive;
  final bool hideContent;
  final void Function(int cell)? onTapCell;

  const BoardWidget({
    super.key,
    required this.values,
    required this.candidates,
    required this.givens,
    this.selectedCell,
    this.highlightDigit,
    this.wrongCells = const {},
    this.roleCells = const {},
    this.roleCandidates = const [],
    this.interactive = true,
    this.hideContent = false,
    this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    // Selection-derived highlight sets (live play only).
    final peerSet = <int>{};
    final sameDigitSet = <int>{};
    final sameNoteSet = <int>{};
    if (interactive) {
      int? highlight;
      if (selectedCell != null) {
        final sel = selectedCell!;
        peerSet.addAll(peers[sel]);
        if (values[sel] != 0) highlight = values[sel];
      }
      // Fall back to the auto-entry pen digit when no filled cell drives the
      // highlight, so picking a number behaves like selecting that digit.
      highlight ??= highlightDigit;
      if (highlight != null) {
        for (var i = 0; i < cellCount; i++) {
          if (values[i] == highlight) {
            sameDigitSet.add(i);
          } else if (maskHas(candidates[i], highlight)) {
            sameNoteSet.add(i);
          }
        }
      }
    }

    final candByCell = <int, List<CandidateMark>>{};
    for (final m in roleCandidates) {
      candByCell.putIfAbsent(m.cell, () => []).add(m);
    }

    final colors = BoardColors.of(context);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.gridLineThick, width: 2),
        ),
        child: Column(
          children: [
            for (var r = 0; r < 9; r++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < 9; c++)
                      Expanded(
                        child: _cell(
                          r * 9 + c,
                          colors,
                          peerSet,
                          sameDigitSet,
                          sameNoteSet,
                          candByCell,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    int i,
    BoardColors colors,
    Set<int> peerSet,
    Set<int> sameDigitSet,
    Set<int> sameNoteSet,
    Map<int, List<CandidateMark>> candByCell,
  ) {
    final r = rowOf(i), c = colOf(i);
    Color bg = colors.cell;
    if (roleCells.containsKey(i)) {
      bg = roleColor(roleCells[i]!).withOpacity(0.35);
    } else if (i == selectedCell) {
      bg = colors.selected;
    } else if (sameDigitSet.contains(i)) {
      bg = colors.sameDigit;
    } else if (sameNoteSet.contains(i)) {
      bg = colors.sameDigitNote;
    } else if (peerSet.contains(i)) {
      bg = colors.peer;
    }

    final border = Border(
      top: BorderSide(
        color: r % 3 == 0 ? colors.gridLineThick : colors.gridLine,
        width: r % 3 == 0 ? 1.5 : 0.5,
      ),
      left: BorderSide(
        color: c % 3 == 0 ? colors.gridLineThick : colors.gridLine,
        width: c % 3 == 0 ? 1.5 : 0.5,
      ),
      right: BorderSide(
        color: c == 8 ? colors.gridLineThick : Colors.transparent,
        width: c == 8 ? 1.5 : 0,
      ),
      bottom: BorderSide(
        color: r == 8 ? colors.gridLineThick : Colors.transparent,
        width: r == 8 ? 1.5 : 0,
      ),
    );

    return GestureDetector(
      onTap: (interactive && onTapCell != null) ? () => onTapCell!(i) : null,
      child: Container(
        decoration: BoxDecoration(color: bg, border: border),
        child: hideContent ? null : _content(i, colors, candByCell[i]),
      ),
    );
  }

  Widget _content(int i, BoardColors colors, List<CandidateMark>? marks) {
    final v = values[i];
    if (v != 0) {
      final isGiven = givens[i] != 0;
      final isWrong = wrongCells.contains(i);
      return Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(0.5),
            child: Text(
              '$v',
              style: TextStyle(
                fontWeight: isGiven ? FontWeight.bold : FontWeight.w500,
                color: isWrong
                    ? colors.wrong
                    : (isGiven ? colors.given : colors.entry),
              ),
            ),
          ),
        ),
      );
    }
    // Pencil marks 3x3.
    final mask = candidates[i];
    if (mask == 0 && (marks == null || marks.isEmpty)) {
      return const SizedBox.shrink();
    }
    final markRole = <int, HighlightRole>{};
    if (marks != null) {
      for (final m in marks) {
        markRole[m.digit] = m.role;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(0.5),
      child: Column(
        children: [
          for (var br = 0; br < 3; br++)
            Expanded(
              child: Row(
                children: [
                  for (var bc = 0; bc < 3; bc++)
                    Expanded(
                        child: _pencil(br * 3 + bc + 1, colors, mask, markRole)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pencil(
      int d, BoardColors colors, int mask, Map<int, HighlightRole> markRole) {
    final present = maskHas(mask, d);
    final role = markRole[d];
    if (!present && role == null) return const SizedBox.shrink();
    final highlighted = role != null;
    return Center(
      child: FittedBox(
        child: Container(
          decoration: highlighted
              ? BoxDecoration(
                  color: roleColor(role).withOpacity(0.5),
                  shape: BoxShape.circle,
                )
              : null,
          padding: const EdgeInsets.all(0.5),
          child: Text(
            '$d',
            style: TextStyle(
              color: highlighted ? colors.pencilHighlight : colors.pencil,
              fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
