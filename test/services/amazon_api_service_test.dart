import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pc_buildere/models/component.dart';
import 'package:pc_buildere/services/amazon_api_service.dart';

void main() {
  AmazonApiService service(
    Future<http.Response> Function(http.Request) handler, {
    bool signedIn = true,
  }) => AmazonApiService(
    client: MockClient(handler),
    auth: MockFirebaseAuth(
      signedIn: signedIn,
      mockUser: MockUser(uid: 'alice'),
    ),
  );

  http.Response error(int status, String code, String message) => http.Response(
    jsonEncode({
      'error': {'code': code, 'message': message},
    }),
    status,
  );

  Future<void> expectMessage(AmazonApiService api, String message) =>
      expectLater(
        api.searchProducts(query: 'ryzen', componentType: ComponentType.cpu),
        throwsA(predicate((e) => e.toString().contains(message))),
      );

  test(
    'search posts to the Worker with the ID token and maps products',
    () async {
      late http.Request sent;
      final api = service((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'products': [
              {
                'asin': 'B000000001',
                'product_title': 'AMD Ryzen 5',
                'product_price': r'$1,199.50',
                'product_url': 'https://amazon.com/x',
              },
            ],
          }),
          200,
        );
      });

      final products = await api.searchProducts(
        query: 'ryzen cpu',
        componentType: ComponentType.cpu,
      );

      expect(sent.url.path, '/search');
      expect(sent.method, 'POST');
      expect(sent.headers['authorization'], startsWith('Bearer '));
      expect(jsonDecode(sent.body), {'query': 'ryzen cpu', 'country': 'US'});
      expect(products.single.id, 'B000000001');
      expect(products.single.brand, 'AMD');
      expect(products.single.price, 1199.5);
    },
  );

  test('product details uses its own route', () async {
    late http.Request sent;
    final api = service((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'product_title': 'RTX',
          'product_price': r'$500',
          'product_photos': ['a.jpg'],
          'about_product': ['Fast'],
        }),
        200,
      );
    });

    final details = await api.getProductDetails(asin: 'B0BBHD5D8Y');

    expect(sent.url.path, '/product-details');
    expect(jsonDecode(sent.body)['asin'], 'B0BBHD5D8Y');
    expect(details.title, 'RTX');
    expect(details.images, ['a.jpg']);
    expect(details.features.single['feature'], 'Fast');
  });

  test('signed-out users get a clear message and no request is sent', () async {
    var called = false;
    final api = service((request) async {
      called = true;
      return http.Response('{}', 200);
    }, signedIn: false);

    await expectMessage(api, 'Please sign in');
    expect(called, isFalse);
  });

  test('rate limit message from the Worker is shown', () async {
    final api = service(
      (_) async =>
          error(429, 'resource-exhausted', 'Too many product requests.'),
    );
    await expectMessage(api, 'Too many product requests.');
  });

  test('expired sign-in maps to the sign-in message', () async {
    final api = service((_) async => error(401, 'unauthenticated', 'x'));
    await expectMessage(api, 'Please sign in');
  });

  test('internal errors are not shown to the user', () async {
    final api = service((_) async => error(500, 'internal', 'secret detail'));
    await expectMessage(api, 'Could not load products');
  });

  test('non-JSON gateway errors do not crash', () async {
    final api = service((_) async => http.Response('<html>502</html>', 502));
    await expectMessage(api, 'Could not load products');
  });

  test('network failures show a connection message', () async {
    final api = service((_) async => throw http.ClientException('offline'));
    await expectMessage(api, 'Could not reach the product service');
  });
}
