import 'package:flutter/material.dart';

import '../data/variant_spec.dart';
import '../engine/constraints/killer_cage.dart';
import '../engine/grid.dart';

/// Paints variant-rule decorations (currently killer cages) over the 9x9 cell
/// grid. The canvas covers exactly the cell area, so a cell of index `i` spans
/// `(colOf(i)*u, rowOf(i)*u)`..`+u` where `u = size.width / 9`.
class ConstraintOverlayPainter extends CustomPainter {
  final VariantSpec variant;
  final Color color;

  ConstraintOverlayPainter({required this.variant, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 9;
    for (final cage in variant.constraints.whereType<KillerCage>()) {
      _paintCage(canvas, u, cage);
    }
  }

  void _paintCage(Canvas canvas, double u, KillerCage cage) {
    final set = cage.cells.toSet();
    final pad = u * 0.09;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    bool inCage(int r, int c) =>
        r >= 0 && r < 9 && c >= 0 && c < 9 && set.contains(r * 9 + c);

    for (final cell in cage.cells) {
      final r = rowOf(cell), c = colOf(cell);
      final left = c * u, top = r * u, right = (c + 1) * u, bottom = (r + 1) * u;
      final topB = !inCage(r - 1, c);
      final botB = !inCage(r + 1, c);
      final leftB = !inCage(r, c - 1);
      final rightB = !inCage(r, c + 1);

      // Each boundary edge is inset by `pad`; where an adjacent perpendicular
      // edge is also a boundary, the endpoint is pulled in so corners meet.
      if (topB) {
        _dashLine(canvas, paint, Offset(left + (leftB ? pad : 0), top + pad),
            Offset(right - (rightB ? pad : 0), top + pad));
      }
      if (botB) {
        _dashLine(canvas, paint, Offset(left + (leftB ? pad : 0), bottom - pad),
            Offset(right - (rightB ? pad : 0), bottom - pad));
      }
      if (leftB) {
        _dashLine(canvas, paint, Offset(left + pad, top + (topB ? pad : 0)),
            Offset(left + pad, bottom - (botB ? pad : 0)));
      }
      if (rightB) {
        _dashLine(canvas, paint, Offset(right - pad, top + (topB ? pad : 0)),
            Offset(right - pad, bottom - (botB ? pad : 0)));
      }
    }

    _paintSum(canvas, u, cage);
  }

  /// Draw the cage total in the corner of its top-left-most cell.
  void _paintSum(Canvas canvas, double u, KillerCage cage) {
    final anchor = cage.cells.reduce((a, b) {
      final ra = rowOf(a), rb = rowOf(b);
      if (ra != rb) return ra < rb ? a : b;
      return colOf(a) <= colOf(b) ? a : b;
    });
    final r = rowOf(anchor), c = colOf(anchor);
    final tp = TextPainter(
      text: TextSpan(
        text: '${cage.sum}',
        style: TextStyle(
          color: color,
          fontSize: u * 0.24,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c * u + u * 0.12, r * u + u * 0.08));
  }

  void _dashLine(Canvas canvas, Paint paint, Offset a, Offset b,
      {double dash = 4, double gap = 3}) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * (covered + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      covered += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant ConstraintOverlayPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.color != color;
}
