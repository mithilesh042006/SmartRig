import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/component.dart';

class ProductDetails {
  final String asin;
  final String title;
  final String? description;
  final String? imageUrl;
  final List<String> images;
  final double price;
  final String? priceDisplay;
  final String? rating;
  final String? reviewCount;
  final String? productUrl;
  final String? brand;
  final List<Map<String, String>> features;

  const ProductDetails({
    required this.asin,
    required this.title,
    this.description,
    this.imageUrl,
    this.images = const [],
    required this.price,
    this.priceDisplay,
    this.rating,
    this.reviewCount,
    this.productUrl,
    this.brand,
    this.features = const [],
  });
}

/// Fetches Amazon products through the Cloudflare Worker in `worker/`, which
/// holds the RapidAPI key and only accepts signed-in Firebase users.
class AmazonApiService {
  static const _baseUrl = 'https://smartrig-proxy.smartrig-proxy.workers.dev';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final FirebaseAuth _auth;

  AmazonApiService({http.Client? client, FirebaseAuth? auth})
    : _client = client ?? http.Client(),
      _auth = auth ?? FirebaseAuth.instance;

  Future<List<Component>> searchProducts({
    required String query,
    required ComponentType componentType,
    String country = 'US',
  }) async {
    // Always enforce component context in search query to prevent irrelevant results
    final componentKeywords = getDefaultQuery(componentType);
    final enforcedQuery = _buildEnforcedQuery(query, componentKeywords);

    final data = await _call('/search', {
      'query': enforcedQuery,
      'country': country,
    });
    final products = data['products'] as List? ?? [];

    return products.map((raw) {
      final product = _asMap(raw);
      return Component(
        id: product['asin'] ?? '',
        name: product['product_title'] ?? 'Unknown Product',
        brand: _extractBrand(product['product_title'] ?? ''),
        type: componentType,
        price: _parsePrice(product['product_price']),
        imageUrl: product['product_photo'],
        specs: {
          'Rating': product['product_star_rating'] ?? 'N/A',
          'Reviews': product['product_num_ratings']?.toString() ?? '0',
          'ProductUrl': product['product_url'] ?? '',
        },
      );
    }).toList();
  }

  /// Fetch detailed product information by ASIN
  Future<ProductDetails> getProductDetails({
    required String asin,
    String country = 'US',
  }) async {
    final product = await _call('/product-details', {
      'asin': asin,
      'country': country,
    });

    // Extract features
    final aboutProduct = product['about_product'] as List? ?? [];
    final features = aboutProduct
        .map((f) => {'feature': f.toString()})
        .toList()
        .cast<Map<String, String>>();

    // Extract images
    final productPhotos = product['product_photos'] as List? ?? [];
    final images = productPhotos.map((p) => p.toString()).toList();

    return ProductDetails(
      asin: asin,
      title: product['product_title'] ?? 'Unknown Product',
      description: product['product_description'],
      imageUrl: product['product_photo'],
      images: images,
      price: _parsePrice(product['product_price']),
      priceDisplay: product['product_price'],
      rating: product['product_star_rating'],
      reviewCount: product['product_num_ratings']?.toString(),
      productUrl: product['product_url'],
      brand: product['product_byline'],
      features: features,
    );
  }

  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, dynamic> params,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please sign in to search products.');

    final http.Response response;
    try {
      final token = await user.getIdToken();
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(params),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your internet connection.',
      );
    } on Exception {
      throw Exception(
        'Could not reach the product service. Please check your internet connection.',
      );
    }

    final body = _decode(response.body);
    if (response.statusCode == 200) return body;

    final error = _asMap(body['error']);
    final message = error['message'] as String?;
    throw Exception(switch (error['code']) {
      'unauthenticated' => 'Please sign in to search products.',
      'deadline-exceeded' =>
        'Request timed out. Please check your internet connection.',
      'resource-exhausted' ||
      'not-found' ||
      'unavailable' => message ?? 'Product service is unavailable.',
      _ => 'Could not load products. Please try again later.',
    });
  }

  // Gateway errors can return HTML instead of JSON
  static Map<String, dynamic> _decode(String body) {
    try {
      return _asMap(jsonDecode(body));
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static double _parsePrice(Object? price) {
    final priceStr = price is String ? price : '\$0';
    return double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  /// Build enforced query by appending component keywords to user's search
  /// This ensures searches stay relevant to the component type
  String _buildEnforcedQuery(String userQuery, String componentKeywords) {
    final normalizedUserQuery = userQuery.toLowerCase().trim();
    final normalizedKeywords = componentKeywords.toLowerCase();

    // Check if user query already contains the main component keywords
    final keywordParts = normalizedKeywords.split(' ');
    final hasKeywords = keywordParts.any(
      (keyword) => keyword.length > 2 && normalizedUserQuery.contains(keyword),
    );

    // If user already included component keywords, use their query
    // Otherwise, append component keywords to ensure relevant results
    if (hasKeywords) {
      return userQuery.trim();
    }
    return '${userQuery.trim()} $componentKeywords';
  }

  String _extractBrand(String title) {
    final words = title.split(' ');
    return words.isNotEmpty ? words.first : 'Unknown';
  }

  /// Get default search query for a component type
  static String getDefaultQuery(ComponentType type) {
    switch (type) {
      case ComponentType.cpu:
        return 'Desktop CPU Processor';
      case ComponentType.gpu:
        return 'Graphics Card GPU';
      case ComponentType.ram:
        return 'Desktop RAM DDR5';
      case ComponentType.motherboard:
        return 'ATX Motherboard';
      case ComponentType.storage:
        return 'SSD NVMe';
      case ComponentType.psu:
        return 'PC Power Supply';
      case ComponentType.pcCase:
        return 'PC Case ATX';
      case ComponentType.cooling:
        return 'CPU Cooler';
    }
  }
}
