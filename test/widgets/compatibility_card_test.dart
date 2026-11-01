import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/services/compatibility_service.dart';
import 'package:pc_buildere/widgets/compatibility_card.dart';

Widget _app(List<CompatibilityCheck> checks) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: CompatibilityCard(report: CompatibilityReport(checks)),
    ),
  ),
);

void main() {
  const pass = CompatibilityCheck(
    'Socket',
    CompatibilityStatus.compatible,
    'Both use AM5.',
  );
  const problem = CompatibilityCheck(
    'Memory',
    CompatibilityStatus.incompatible,
    'The RAM will not fit.',
  );
  const unverified = CompatibilityCheck(
    'GPU length',
    CompatibilityStatus.unknown,
    'Not available.',
  );

  testWidgets('shows nothing until there is something to check', (
    tester,
  ) async {
    await tester.pumpWidget(_app([]));
    expect(find.text('Compatibility'), findsNothing);
  });

  testWidgets('problems are summarized and expanded', (tester) async {
    await tester.pumpWidget(_app([pass, problem, unverified]));
    expect(find.text('1 problem · 1 not verified'), findsOneWidget);
    expect(find.text('The RAM will not fit.'), findsOneWidget);
  });

  testWidgets('unknown results are never reported as passing', (tester) async {
    await tester.pumpWidget(_app([pass, unverified]));
    expect(find.text('1 not verified'), findsOneWidget);
    expect(find.text('All checks passed'), findsNothing);
  });

  testWidgets('a clean build says so and stays collapsed', (tester) async {
    await tester.pumpWidget(_app([pass]));
    expect(find.text('All checks passed'), findsOneWidget);
    expect(find.text('Both use AM5.'), findsNothing);
  });
}
