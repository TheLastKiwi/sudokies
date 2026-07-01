import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/variant_spec.dart';
import '../engine/constraints/arrow.dart';
import '../engine/constraints/killer_cage.dart';
import '../engine/constraints/pair_dot.dart';
import '../engine/constraints/thermometer.dart';
import '../engine/grid.dart';

/// Paints variant-rule decorations (killer cages, thermometers, arrows) over the
/// 9x9 cell grid. The canvas covers exactly the cell area, so a cell of index
/// `i` spans `(colOf(i)*u, rowOf(i)*u)`..`+u` where `u = size.width / 9`.
class ConstraintOverlayPainter extends CustomPainter {
  final VariantSpec variant;
  final Color cageColor;
  final Color lineColor;
  final Color cellColor;

  ConstraintOverlayPainter({
    required this.variant,
    required this.cageColor,
    required this.lineColor,
    required this.cellColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 9;
    // Lines/arrows first so cage outlines and sums stay readable on top.
    for (final c in variant.constraints) {
      if (c is Thermometer) _paintThermo(canvas, u, c);
      if (c is Arrow) _paintArrow(canvas, u, c);
    }
    for (final cage in variant.constraints.whereType<KillerCage>()) {
      _paintCage(canvas, u, cage);
    }
    // Edge dots sit on top of everything so they stay visible.
    for (final dot in variant.constraints.whereType<PairDot>()) {
      _paintDot(canvas, u, dot);
    }
  }

  // ---- Kropki / ratio / sum dot ------------------------------------------
  void _paintDot(Canvas canvas, double u, PairDot dot) {
    final center = Offset(
      ((colOf(dot.a) + colOf(dot.b)) / 2 + 0.5) * u,
      ((rowOf(dot.a) + rowOf(dot.b)) / 2 + 0.5) * u,
    );
    if (dot.kind == PairDotKind.sum) {
      canvas.drawCircle(center, u * 0.18, Paint()..color = cellColor);
      final label =
          dot.value == 10 ? 'X' : (dot.value == 5 ? 'V' : '${dot.value}');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: lineColor,
            fontSize: u * 0.28,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final r = u * 0.11;
    canvas.drawCircle(center, r + u * 0.02, Paint()..color = cellColor);
    if (dot.kind == PairDotKind.ratio) {
      canvas.drawCircle(center, r, Paint()..color = lineColor); // filled (black)
    } else {
      canvas.drawCircle(center, r, Paint()..color = cellColor); // hollow (white)
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.035,
      );
    }
  }

  Offset _center(double u, int cell) =>
      Offset((colOf(cell) + 0.5) * u, (rowOf(cell) + 0.5) * u);

  // ---- Thermometer --------------------------------------------------------
  void _paintThermo(Canvas canvas, double u, Thermometer t) {
    if (t.path.isEmpty) return;
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path()..moveTo(_center(u, t.path.first).dx, _center(u, t.path.first).dy);
    for (final c in t.path.skip(1)) {
      p.lineTo(_center(u, c).dx, _center(u, c).dy);
    }
    canvas.drawPath(p, stroke);
    // Bulb.
    canvas.drawCircle(
      _center(u, t.path.first),
      u * 0.30,
      Paint()..color = lineColor,
    );
  }

  // ---- Arrow --------------------------------------------------------------
  void _paintArrow(Canvas canvas, double u, Arrow a) {
    if (a.bulb.isEmpty || a.path.isEmpty) return;
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final start = _center(u, a.bulb.first);
    final points = [start, for (final c in a.path) _center(u, c)];
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p, stroke);

    // Hollow bulb circle(s).
    for (final b in a.bulb) {
      canvas.drawCircle(
        _center(u, b),
        u * 0.30,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06,
      );
    }

    // Arrowhead at the tip along the last segment's direction.
    final tip = points.last;
    final prev = points[points.length - 2];
    final ang = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
    const spread = math.pi / 7;
    final len = u * 0.26;
    for (final s in [ang + math.pi - spread, ang + math.pi + spread]) {
      canvas.drawLine(
        tip,
        Offset(tip.dx + len * math.cos(s), tip.dy + len * math.sin(s)),
        stroke,
      );
    }
  }

  // ---- Killer cage --------------------------------------------------------
  void _paintCage(Canvas canvas, double u, KillerCage cage) {
    final set = cage.cells.toSet();
    final pad = u * 0.09;
    final paint = Paint()
      ..color = cageColor
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
          color: cageColor,
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
      oldDelegate.variant != variant ||
      oldDelegate.cageColor != cageColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.cellColor != cellColor;
}
