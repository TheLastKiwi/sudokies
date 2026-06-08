import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudokies/ui/board_widget.dart';

void main() {
  testWidgets('BoardWidget renders given digits', (WidgetTester tester) async {
    final values = List<int>.filled(81, 0);
    final givens = List<int>.filled(81, 0);
    // Place a few givens.
    values[0] = 5;
    givens[0] = 5;
    values[40] = 3;
    givens[40] = 3;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            values: values,
            candidates: List<int>.filled(81, 0),
            givens: givens,
            interactive: false,
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('BoardWidget reports taps when interactive', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            values: List<int>.filled(81, 0),
            candidates: List<int>.filled(81, 0),
            givens: List<int>.filled(81, 0),
            onTapCell: (i) => tapped = i,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(BoardWidget));
    expect(tapped, isNotNull);
  });
}
