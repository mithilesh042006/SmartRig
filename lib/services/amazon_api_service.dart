import 'dart:convert';
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

class AmazonApiService {
  static const String _baseUrl = 'real-time-amazon-data.p.rapidapi.com';
  static const String _apiKey =
      '310a2adbf0msh08eba5ec09aee90p10ef54jsnaf7e9db0f974';
  static const String _apiHost = 'real-time-amazon-data.p.rapidapi.com';

  Future<List<Component>> searchProducts({
    required String query,
    required ComponentType componentType,
    String country = 'US',
  }) async {
    // Always enforce component context in search query to prevent irrelevant results
    final componentKeywords = getDefaultQuery(componentType);
    final enforcedQuery = _buildEnforcedQuery(query, componentKeywords);

    final uri = Uri.https(_baseUrl, '/search', {
      'query': enforcedQuery,
      'country': country,
      'page': '1',
    });

    try {
      final response = await http
          .get(
            uri,
            headers: {'x-rapidapi-key': _apiKey, 'x-rapidapi-host': _apiHost},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final products = data['data']?['products'] as List? ?? [];

        return products.take(10).map((product) {
          final priceStr = product['product_price'] as String? ?? '\$0';
          final priceValue =
              double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ??
              0.0;

          return Component(
            id: product['asin'] ?? '',
            name: product['product_title'] ?? 'Unknown Product',
            brand: _extractBrand(product['product_title'] ?? ''),
            type: componentType,
            price: priceValue,
            imageUrl: product['product_photo'],
            specs: {
              'Rating': product['product_star_rating'] ?? 'N/A',
              'Reviews': product['product_num_ratings']?.toString() ?? '0',
              'ProductUrl': product['product_url'] ?? '',
            },
          );
        }).toList();
      } else if (response.statusCode == 403) {
        throw Exception(
          'API key invalid or expired. Please check your RapidAPI subscription.',
        );
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timed out. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// Fetch detailed product information by ASIN
  Future<ProductDetails> getProductDetails({
    required String asin,
    String country = 'US',
  }) async {
    final uri = Uri.https(_baseUrl, '/product-details', {
      'asin': asin,
      'country': country,
    });

    final response = await http.get(
      uri,
      headers: {'x-rapidapi-key': _apiKey, 'x-rapidapi-host': _apiHost},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final product = data['data'] ?? {};

      final priceStr = product['product_price'] as String? ?? '\$0';
      final priceValue =
          double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

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
        price: priceValue,
        priceDisplay: product['product_price'],
        rating: product['product_star_rating'],
        reviewCount: product['product_num_ratings']?.toString(),
        productUrl: product['product_url'],
        brand: product['product_byline'],
        features: features,
      );
    } else {
      throw Exception('Failed to load product details: ${response.statusCode}');
    }
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
