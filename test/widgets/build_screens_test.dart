import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/providers/build_provider.dart';
import 'package:pc_buildere/screens/builder_screen.dart';
import 'package:pc_buildere/screens/review_build_screen.dart';

Component _part(ComponentType type, String name) =>
    Component(id: name, name: name, brand: '', type: type, price: 100);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Map<ComponentType, String> parts,
) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  parts.forEach((type, name) {
    container.read(buildProvider.notifier).selectComponent(_part(type, name));
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}

const _incompatible = {
  ComponentType.cpu: 'Intel Core i5-13600K',
  ComponentType.motherboard: 'MSI B650 ATX',
  ComponentType.gpu: 'NVIDIA RTX 4070',
};

const _compatible = {
  ComponentType.cpu: 'AMD Ryzen 5 7600X',
  ComponentType.motherboard: 'MSI B650 ATX',
  ComponentType.gpu: 'NVIDIA RTX 4070',
};

void main() {
  group('builder', () {
    testWidgets('shows a socket conflict', (tester) async {
      await _pump(tester, const BuilderScreen(), _incompatible);
      expect(find.text('1 problem'), findsOneWidget);
      expect(find.textContaining('LGA1700'), findsOneWidget);
    });

    testWidgets('has no card until parts can be compared', (tester) async {
      await _pump(tester, const BuilderScreen(), {
        ComponentType.cpu: 'AMD Ryzen 5 7600X',
      });
      expect(find.text('Compatibility'), findsNothing);
    });
  });

  group('review', () {
    testWidgets('labels scores and FPS as estimates', (tester) async {
      await _pump(tester, const ReviewBuildScreen(), _compatible);
      expect(tester.takeException(), isNull);
      expect(find.text('Estimated System Score'), findsOneWidget);
      expect(find.text('Estimated Gaming FPS'), findsOneWidget);
      expect(find.textContaining('rough estimates'), findsOneWidget);
      expect(find.textContaining('no performance data'), findsNothing);
    });

    testWidgets('flags parts missing from the index', (tester) async {
      await _pump(tester, const ReviewBuildScreen(), {
        ComponentType.cpu: 'AMD Ryzen 5 7600X',
        ComponentType.gpu: 'Mystery Graphics',
      });
      expect(find.textContaining('this GPU'), findsOneWidget);
    });

    testWidgets('renders very fast builds without clipping errors', (
      tester,
    ) async {
      await _pump(tester, const ReviewBuildScreen(), {
        ComponentType.cpu: 'AMD Ryzen 7 9800X3D',
        ComponentType.gpu: 'NVIDIA RTX 5090',
      });
      expect(tester.takeException(), isNull);
      expect(find.text('Extreme'), findsWidgets);
    });

    testWidgets('save dialog warns about problems but still allows saving', (
      tester,
    ) async {
      await _pump(tester, const ReviewBuildScreen(), _incompatible);
      await tester.tap(find.text('Save Build').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('compatibility problem'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    });

    testWidgets('save dialog is quiet for a compatible build', (tester) async {
      await _pump(tester, const ReviewBuildScreen(), _compatible);
      await tester.tap(find.text('Save Build').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('compatibility problem'), findsNothing);
    });
  });
}
