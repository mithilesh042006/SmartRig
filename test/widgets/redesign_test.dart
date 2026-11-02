import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/providers/build_provider.dart';
import 'package:pc_buildere/providers/navigation_provider.dart';
import 'package:pc_buildere/providers/theme_provider.dart';
import 'package:pc_buildere/screens/build_3d_viewer_screen.dart';
import 'package:pc_buildere/screens/builder_screen.dart';
import 'package:pc_buildere/screens/community_screen.dart';
import 'package:pc_buildere/screens/compare_builds_screen.dart';
import 'package:pc_buildere/screens/component_selection_screen.dart';
import 'package:pc_buildere/screens/home_screen.dart';
import 'package:pc_buildere/screens/login_screen.dart';
import 'package:pc_buildere/screens/main_navigation_screen.dart';
import 'package:pc_buildere/screens/product_detail_screen.dart';
import 'package:pc_buildere/screens/profile_screen.dart';
import 'package:pc_buildere/screens/register_screen.dart';
import 'package:pc_buildere/screens/review_build_screen.dart';
import 'package:pc_buildere/screens/saved_builds_screen.dart';
import 'package:pc_buildere/services/amazon_api_service.dart';
import 'package:pc_buildere/services/saved_builds_service.dart';
import 'package:pc_buildere/theme/app_theme.dart';
import 'package:pc_buildere/theme/app_tokens.dart';
import 'package:pc_buildere/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('colour tokens', () {
    for (final (name, c) in [
      ('light', RigColors.light),
      ('dark', RigColors.dark),
    ]) {
      test('$name text meets WCAG AA on its surfaces', () {
        for (final surface in [c.background, c.surface, c.surfaceRaised]) {
          expect(_contrast(c.textPrimary, surface), greaterThanOrEqualTo(4.5));
        }
        for (final foreground in [
          c.textSecondary,
          c.accent,
          c.success,
          c.warning,
          c.error,
        ]) {
          expect(
            _contrast(foreground, c.surface),
            greaterThanOrEqualTo(4.5),
            reason: foreground.toString(),
          );
        }
      });

      test('$name buttons and hero text are readable', () {
        expect(_contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        for (final hero in [c.heroStart, c.heroEnd]) {
          expect(_contrast(c.onHero, hero), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.onHeroMuted, hero), greaterThanOrEqualTo(4.5));
        }
      });
    }

    test('each theme carries its own tokens', () {
      expect(
        AppTheme.light(googleFonts: false).extension<RigColors>(),
        RigColors.light,
      );
      expect(
        AppTheme.dark(googleFonts: false).extension<RigColors>(),
        RigColors.dark,
      );
    });
  });

  group('theme preference', () {
    Future<ThemeMode> reload() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeProvider);
      await Future<void>.delayed(Duration.zero);
      return container.read(themeProvider);
    }

    test('defaults to system', () async {
      expect(await reload(), ThemeMode.system);
    });

    test('light, dark and system each survive a restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeProvider.notifier);

      for (final mode in ThemeMode.values) {
        await notifier.setTheme(mode);
        expect(await reload(), mode);
      }
    });

    testWidgets('profile offers all three modes and applies a choice', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const ProfileScreen());
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(container.read(themeProvider), ThemeMode.dark);
    });
  });

  group('no layout overflow', () {
    final screens = <String, (Widget, Map<ComponentType, Component>?)>{
      'navigation': (const MainNavigationScreen(), null),
      'home': (const HomeScreen(), null),
      'builder': (const BuilderScreen(), sampleParts()),
      'empty builder': (const BuilderScreen(), null),
      'selection': (
        const ComponentSelectionScreen(componentType: ComponentType.gpu),
        null,
      ),
      'product': (
        ProductDetailScreen(
          component: part(ComponentType.cpu, 'AMD Ryzen 7 7800X3D', 349.99),
          canAddToBuild: true,
        ),
        null,
      ),
      'review': (const ReviewBuildScreen(), sampleParts()),
      'saved': (const SavedBuildsScreen(), null),
      'compare': (const CompareBuildsScreen(), null),
      'community': (const CommunityScreen(), null),
      'profile': (const ProfileScreen(), null),
      'login': (const LoginScreen(), null),
      'register': (const RegisterScreen(), null),
      'viewer without a case': (const Build3DViewerScreen(), null),
    };
    final setups = <String, (Size, double, bool)>{
      'small phone': (const Size(320, 568), 1.0, false),
      'small phone, dark': (const Size(320, 568), 1.0, true),
      'large text': (const Size(390, 844), 1.5, false),
      'tablet, dark': (const Size(1024, 768), 1.0, true),
    };

    for (final screen in screens.entries) {
      for (final setup in setups.entries) {
        testWidgets('${screen.key}, ${setup.key}', (tester) async {
          await pumpScreen(
            tester,
            screen.value.$1,
            parts: screen.value.$2,
            size: setup.value.$1,
            textScale: setup.value.$2,
            dark: setup.value.$3,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('home', () {
    testWidgets('shows real counts and recent builds', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(390, 1600));
      expect(find.text('3'), findsOneWidget); // saved
      expect(find.text('1'), findsOneWidget); // public
      expect(find.text('2'), findsOneWidget); // private
      expect(find.text('Gaming Beast'), findsOneWidget);
      expect(find.text('Welcome back, Alice'), findsOneWidget);
    });

    testWidgets('new users get an empty state, not sample data', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        builds: const [],
        size: const Size(390, 1600),
      );
      expect(find.text('No saved builds yet'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('Start Building opens the Build tab', (tester) async {
      final container = await pumpScreen(tester, const HomeScreen());
      await tester.tap(find.text('Start Building'));
      expect(container.read(selectedTabProvider), AppTab.build);
    });

    testWidgets('the hero reflects a build in progress', (tester) async {
      await pumpScreen(tester, const HomeScreen(), parts: sampleParts());
      expect(find.text('Continue Building (8/8)'), findsOneWidget);
    });

    testWidgets('a recent build reopens in the builder', (tester) async {
      final container = await pumpScreen(
        tester,
        const HomeScreen(),
        size: const Size(390, 1600),
      );
      await tester.tap(find.text('Gaming Beast'));
      await tester.pump();
      expect(container.read(selectedTabProvider), AppTab.build);
      expect(container.read(buildProvider).selectedComponents.length, 8);
    });
  });

  group('navigation', () {
    testWidgets('has the four tabs and switches between them', (tester) async {
      final container = await pumpScreen(tester, const MainNavigationScreen());
      for (final label in ['Home', 'Build', 'Saved', 'Profile']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('Saved'));
      await tester.pump();
      expect(container.read(selectedTabProvider), AppTab.saved);
    });

    testWidgets('community stays reachable from home', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(390, 1600));
      await tester.tap(find.text('Community builds'));
      await tester.pumpAndSettle();
      expect(find.text('Community Builds'), findsOneWidget);
    });
  });

  group('builder', () {
    testWidgets('lists all eight slots and tracks progress', (tester) async {
      await pumpScreen(
        tester,
        const BuilderScreen(),
        parts: {ComponentType.cpu: part(ComponentType.cpu, 'Ryzen', 100)},
        size: const Size(390, 1400),
      );
      for (final label in [
        'CPU',
        'Motherboard',
        'GPU',
        'RAM',
        'Storage',
        'Power Supply',
        'Case',
        'Cooling',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('1/8'), findsOneWidget);
      expect(find.text('7 more to complete this build'), findsOneWidget);
    });

    testWidgets('review stays disabled until a part is selected', (
      tester,
    ) async {
      await pumpScreen(tester, const BuilderScreen());
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Review Build'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('clearing asks first', (tester) async {
      final container = await pumpScreen(
        tester,
        const BuilderScreen(),
        parts: sampleParts(),
      );
      await tester.tap(find.byTooltip('Clear build'));
      await tester.pumpAndSettle();
      expect(container.read(buildProvider).selectedComponents, isNotEmpty);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(container.read(buildProvider).selectedComponents, isEmpty);
    });
  });

  group('component selection', () {
    testWidgets('searches only on submit', (tester) async {
      final queries = <String>[];
      final container = ProviderContainer(
        overrides: [
          componentsProvider.overrideWith((ref, args) async {
            queries.add(args.query);
            return <Component>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(googleFonts: false),
            home: const ComponentSelectionScreen(
              componentType: ComponentType.cpu,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(queries, ['']);

      await tester.enterText(find.byType(TextField), 'ryzen');
      await tester.pump();
      expect(queries, ['']);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(queries, ['', 'ryzen']);
    });

    testWidgets('brand then model builds the existing query', (tester) async {
      final queries = <String>[];
      final container = ProviderContainer(
        overrides: [
          componentsProvider.overrideWith((ref, args) async {
            queries.add(args.query);
            return <Component>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(googleFonts: false),
            home: const ComponentSelectionScreen(
              componentType: ComponentType.cpu,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('AMD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ryzen 7'));
      await tester.pump();
      expect(queries.last, 'AMD Ryzen 7');
    });

    testWidgets('products show price, rating, and an honest missing price', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ComponentSelectionScreen(componentType: ComponentType.cpu),
        size: const Size(390, 1400),
      );
      expect(find.text(r'$199.50'), findsOneWidget);
      expect(find.text('Price unavailable'), findsOneWidget);
      expect(find.text('(6146 reviews)'), findsWidgets);
    });

    testWidgets('quick add puts the part in the build and goes back', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComponentSelectionScreen(
                  componentType: ComponentType.cpu,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(
        container
            .read(buildProvider)
            .selectedComponents[ComponentType.cpu]
            ?.price,
        199.5,
      );
    });
  });

  group('product detail', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      ProductDetails details,
    ) async {
      final container = ProviderContainer(
        overrides: [
          productDetailsProvider.overrideWith((ref, asin) async => details),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(googleFonts: false),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  // Stands in for the selection screen under the detail page.
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const Scaffold()),
                  );
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        component: Component(
                          id: 'A1',
                          name: 'Search title',
                          brand: 'AMD',
                          type: ComponentType.cpu,
                          price: 299,
                          imageUrl: 'search.jpg',
                        ),
                        canAddToBuild: true,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('a details response without a price keeps the known price', (
      tester,
    ) async {
      final container = await open(
        tester,
        const ProductDetails(asin: 'A1', title: 'Full title', price: 0),
      );
      await tester.tap(find.text('Add to Build'));
      await tester.pumpAndSettle();

      final added = container
          .read(buildProvider)
          .selectedComponents[ComponentType.cpu]!;
      expect(added.price, 299);
      expect(added.name, 'Full title');
      expect(added.imageUrl, 'search.jpg');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('missing description and features are simply left out', (
      tester,
    ) async {
      await open(
        tester,
        const ProductDetails(asin: 'A1', title: 'Full title', price: 10),
      );
      expect(find.text('Description'), findsNothing);
      expect(find.text('Key features'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a part already in the build offers only the Amazon link', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        ProductDetailScreen(
          component: part(ComponentType.cpu, 'AMD Ryzen 7 7800X3D', 349.99),
        ),
      );
      expect(find.text('Buy on Amazon'), findsOneWidget);
      expect(find.text('Add to Build'), findsNothing);
    });
  });

  group('saved builds', () {
    testWidgets('shows status and no score without a CPU and GPU', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SavedBuildsScreen(),
        size: const Size(390, 1200),
      );
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsNWidgets(2));
      expect(find.textContaining('Est. score'), findsNWidgets(2));
      expect(find.text('1 part'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation', (tester) async {
      await pumpScreen(tester, const SavedBuildsScreen());
      await tester.tap(find.byTooltip('Delete Gaming Beast'));
      await tester.pumpAndSettle();
      expect(find.text('Delete build?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Gaming Beast'), findsOneWidget);
    });

    testWidgets('the empty state leads to the builder', (tester) async {
      final container = await pumpScreen(
        tester,
        const SavedBuildsScreen(),
        builds: const [],
      );
      await tester.tap(find.text('Start Building'));
      expect(container.read(selectedTabProvider), AppTab.build);
    });
  });

  group('compare', () {
    testWidgets('selection survives a stream update', (tester) async {
      final controller = StreamController<List<SavedBuild>>();
      addTearDown(() {
        controller.close();
      });
      final container = ProviderContainer(
        overrides: [
          savedBuildsStreamProvider.overrideWith((ref) => controller.stream),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(googleFonts: false),
            home: const CompareBuildsScreen(),
          ),
        ),
      );
      controller.add(sampleBuilds);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Gaming Beast'));
      await tester.pump();

      // Firestore re-emits, creating new objects with the same IDs.
      controller.add([for (final b in sampleBuilds) sampleBuild(b.id, b.name)]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Quiet Workstation'));
      await tester.pump();
      expect(find.text('Compare 2 builds'), findsOneWidget);
    });

    testWidgets('needs two builds and stops at three', (tester) async {
      await pumpScreen(tester, const CompareBuildsScreen());
      expect(find.text('Select at least 2 builds'), findsOneWidget);
      for (final name in [
        'Gaming Beast',
        'Quiet Workstation',
        'CPU Only Starter',
      ]) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      expect(find.text('Compare 3 builds'), findsOneWidget);
    });

    testWidgets('shows aligned estimates and declares no winner', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const CompareBuildsScreen(),
        size: const Size(900, 1200),
      );
      for (final name in [
        'Gaming Beast',
        'Quiet Workstation',
        'CPU Only Starter',
      ]) {
        await tester.tap(find.text(name));
        await tester.pump();
      }
      await tester.tap(find.text('Compare 3 builds'));
      await tester.pump();

      expect(find.text('Estimated FPS (1080p)'), findsNWidgets(2));
      expect(find.text('Valorant'), findsNWidgets(2));
      expect(
        find.textContaining('Add a CPU and GPU to this build'),
        findsOneWidget,
      );
      expect(find.textContaining('Winner'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('community', () {
    Future<void> openSheet(WidgetTester tester) async {
      await pumpScreen(tester, const CommunityScreen());
      await tester.tap(find.text('Gaming Beast'));
      await tester.pumpAndSettle();
    }

    testWidgets('card shows author, price, and likes', (tester) async {
      await pumpScreen(tester, const CommunityScreen());
      expect(find.text('Alice Builder'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('details show parts, comments, and an input', (tester) async {
      await openSheet(tester);
      expect(find.text('by Alice Builder'), findsOneWidget);
      expect(find.text('Motherboard'), findsOneWidget);
      expect(find.text('Write a comment...'), findsOneWidget);
      await tester.dragUntilVisible(
        find.textContaining('Clean build'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      expect(find.textContaining('Clean build'), findsOneWidget);
    });

    testWidgets('the build owner can delete any comment', (tester) async {
      await openSheet(tester);
      await tester.dragUntilVisible(
        find.textContaining('Clean build'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      // alice owns the build, so bob's comment is deletable too.
      expect(find.byTooltip('Delete comment'), findsWidgets);
    });

    testWidgets('the comment input stays above the keyboard', (tester) async {
      await openSheet(tester);
      final before = tester.getBottomLeft(find.byType(TextField)).dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final after = tester.getBottomLeft(find.byType(TextField)).dy;
      expect(after, lessThan(before));
      expect(after, lessThanOrEqualTo(844 - 300));
    });
  });

  group('3D viewer', () {
    testWidgets('asks for a case first', (tester) async {
      await pumpScreen(tester, const Build3DViewerScreen());
      expect(find.text('Select a case first'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('icon-only builder actions are labelled', (tester) async {
      await pumpScreen(
        tester,
        const BuilderScreen(),
        parts: {ComponentType.cpu: part(ComponentType.cpu, 'Ryzen', 100)},
      );
      expect(find.byTooltip('Change CPU'), findsOneWidget);
      expect(find.byTooltip('Add GPU'), findsOneWidget);
      expect(find.byTooltip('Clear build'), findsOneWidget);
    });

    testWidgets('the gauge announces its value', (tester) async {
      await pumpScreen(
        tester,
        const ReviewBuildScreen(),
        parts: sampleParts(),
        size: const Size(390, 2400),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Estimated system score \d+, ')),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion skips the gauge animation', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(googleFonts: false),
            home: Builder(
              builder: (context) {
                expect(Motion.of(context, Motion.slow), Duration.zero);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });

  group('formatters', () {
    test('money groups thousands', () {
      expect(formatMoney(1234.5), r'$1,234.50');
      expect(formatMoney(1234567.891), r'$1,234,567.89');
      expect(formatMoney(999), r'$999.00');
      expect(formatMoney(2441.92, decimals: 0), r'$2,442');
      expect(formatMoney(0), r'$0.00');
    });

    test('a missing price is not shown as free', () {
      expect(formatPrice(0), 'Price unavailable');
      expect(formatPrice(49.5), r'$49.50');
    });

    test('dates and relative times', () {
      expect(formatDate(DateTime(2026, 11, 2)), 'Nov 2, 2026');
      expect(formatDate(null), 'Unknown');
      final now = DateTime(2026, 11, 2, 12);
      expect(timeAgo(now, now: now), 'Just now');
      expect(timeAgo(DateTime(2026, 11, 2, 11, 30), now: now), '30m ago');
      expect(timeAgo(DateTime(2026, 11, 2, 9), now: now), '3h ago');
      expect(timeAgo(DateTime(2026, 10, 31, 12), now: now), '2d ago');
    });

    test('initials', () {
      expect(initialsOf('Alice Builder'), 'AB');
      expect(initialsOf('alice'), 'A');
      expect(initialsOf('Mary Jane  Watson'), 'MW');
      expect(initialsOf('   '), '?');
    });

    test('errors lose the Exception prefix', () {
      expect(
        friendlyError(Exception('Too many requests')),
        'Too many requests',
      );
      expect(friendlyError('plain'), 'plain');
    });
  });
}
