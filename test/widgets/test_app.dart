import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/providers/build_provider.dart';
import 'package:pc_buildere/screens/product_detail_screen.dart';
import 'package:pc_buildere/services/amazon_api_service.dart';
import 'package:pc_buildere/services/auth_service.dart';
import 'package:pc_buildere/services/saved_builds_service.dart';
import 'package:pc_buildere/theme/app_theme.dart';

Component part(ComponentType type, String name, double price) => Component(
  id: name,
  name: name,
  brand: name.split(' ').first,
  type: type,
  price: price,
  specs: const {'Rating': '4.8', 'Reviews': '6146'},
);

/// A complete build with real Amazon titles and one socket conflict-free set.
final samplePartNames = {
  ComponentType.cpu: 'AMD Ryzen 7 7800X3D 8-Core, 16-Thread Desktop Processor',
  ComponentType.motherboard:
      'GIGABYTE B650 AORUS Elite AX AMD AM5 ATX Motherboard, DDR5',
  ComponentType.gpu: 'ASUS TUF Gaming GeForce RTX 5070 12GB GDDR7 OC Edition',
  ComponentType.ram: 'CORSAIR Vengeance RS DDR5 32GB (2 x 16GB) Up to 6000MHz',
  ComponentType.storage: 'Samsung 990 PRO 2TB NVMe SSD',
  ComponentType.psu: 'CORSAIR RM850e (2025) ATX 3.1 850W Power Supply',
  ComponentType.pcCase: 'NZXT H5 Flow - Compact ATX Mid-Tower PC Case',
  ComponentType.cooling: 'be quiet! Pure Rock Pro 3 Air CPU Cooler, 250W TDP',
};

Map<ComponentType, Component> sampleParts() => {
  for (final (i, entry) in samplePartNames.entries.indexed)
    entry.key: part(entry.key, entry.value, 89.99 + i * 61.5),
};

SavedBuild sampleBuild(
  String id,
  String name, {
  bool isPublic = false,
  int likes = 0,
  Map<ComponentType, Component>? components,
}) {
  final parts = components ?? sampleParts();
  return SavedBuild(
    id: id,
    name: name,
    components: parts,
    totalPrice: parts.values.fold(0, (sum, p) => sum + p.price),
    createdAt: DateTime(2026, 10, 28),
    userId: 'alice',
    isPublic: isPublic,
    authorName: 'Alice Builder',
    likesCount: likes,
    likedBy: likes > 0 ? const ['alice'] : const [],
  );
}

final sampleBuilds = [
  sampleBuild('b1', 'Gaming Beast', isPublic: true, likes: 12),
  sampleBuild('b2', 'Quiet Workstation'),
  sampleBuild(
    'b3',
    'CPU Only Starter',
    components: {
      ComponentType.cpu: part(ComponentType.cpu, 'AMD Ryzen 5 5600X', 149),
    },
  ),
];

final sampleComments = [
  BuildComment(
    id: 'c1',
    buildId: 'b1',
    userId: 'bob',
    userName: 'Bob Stone',
    text: 'Clean build. How are the temperatures under load?',
    createdAt: DateTime(2026, 10, 30),
  ),
  BuildComment(
    id: 'c2',
    buildId: 'b1',
    userId: 'alice',
    userName: 'Alice Builder',
    text: 'Staying well under 80 degrees so far.',
    createdAt: DateTime(2026, 10, 31),
  ),
];

const sampleDetails = ProductDetails(
  asin: 'B0BTZB7F88',
  title: 'AMD Ryzen 7 7800X3D 8-Core, 16-Thread Desktop Processor',
  description:
      'Eight cores and sixteen threads with AMD 3D V-Cache technology.',
  images: ['a.jpg', 'b.jpg', 'c.jpg'],
  price: 349.99,
  priceDisplay: r'$349.99',
  rating: '4.8',
  reviewCount: '6146',
  productUrl: 'https://www.amazon.com/dp/B0BTZB7F88',
  brand: 'AMD',
  features: [
    {'feature': 'Socket AM5, 8 cores and 16 threads'},
    {'feature': 'Boost clock up to 5.0 GHz'},
  ],
);

final testUser = MockUser(
  uid: 'alice',
  email: 'alice@example.com',
  displayName: 'Alice Builder',
);

/// Provider overrides that replace Firebase and the network with sample data.
List overrides({List<SavedBuild>? builds, bool withUser = true}) {
  final list = builds ?? sampleBuilds;
  return [
    if (withUser) currentUserProvider.overrideWithValue(testUser),
    savedBuildsStreamProvider.overrideWith((ref) => Stream.value(list)),
    publicBuildsStreamProvider.overrideWith(
      (ref) => Stream.value(list.where((b) => b.isPublic).toList()),
    ),
    buildCommentsProvider.overrideWith(
      (ref, id) => Stream.value(sampleComments),
    ),
    savedBuildsServiceProvider.overrideWithValue(
      SavedBuildsService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: true, mockUser: testUser),
      ),
    ),
    componentsProvider.overrideWith(
      (ref, args) async => [
        for (final (i, entry) in samplePartNames.entries.indexed)
          part(args.type, entry.value, i == 2 ? 0 : 199.5 + i * 40),
      ],
    ),
    productDetailsProvider.overrideWith((ref, asin) async => sampleDetails),
  ];
}

/// Pumps [screen] in the real theme, without downloading fonts.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Map<ComponentType, Component>? parts,
  List<SavedBuild>? builds,
  bool dark = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: overrides(builds: builds).cast(),
  );
  addTearDown(container.dispose);
  parts?.values.forEach(container.read(buildProvider.notifier).selectComponent);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(googleFonts: false),
        darkTheme: AppTheme.dark(googleFonts: false),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  return container;
}
