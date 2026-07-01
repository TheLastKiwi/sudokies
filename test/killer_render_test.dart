import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudokies/data/variant_spec.dart';
import 'package:sudokies/engine/constraints/killer_cage.dart';
import 'package:sudokies/ui/board_widget.dart';

void main() {
  testWidgets('BoardWidget paints a killer overlay without error',
      (tester) async {
    final givens = List<int>.filled(81, 0);
    for (var i = 0; i < 9; i++) {
      givens[i] = i + 1;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: BoardWidget(
                values: givens,
                candidates: List<int>.filled(81, 0),
                givens: givens,
                interactive: false,
                variant: const VariantSpec(
                  name: 'Killer',
                  type: 'killer',
                  constraints: [
                    KillerCage([0, 1, 2], 12),
                    KillerCage([11, 20, 19], 19),
                    KillerCage([40, 49], 7),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Stack + CustomPaint overlay build and paint without throwing.
    expect(tester.takeException(), isNull);
    expect(find.byType(BoardWidget), findsOneWidget);
  });
}
