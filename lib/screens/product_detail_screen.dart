import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';
import '../services/amazon_api_service.dart';

// Provider for fetching product details
final productDetailsProvider = FutureProvider.family<ProductDetails, String>((
  ref,
  asin,
) async {
  final apiService = ref.watch(amazonApiServiceProvider);
  return apiService.getProductDetails(asin: asin);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Component component;

  const ProductDetailScreen({super.key, required this.component});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _selectedImageUrl;

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(productDetailsProvider(widget.component.id));

    return Scaffold(
      body: detailsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product details...'),
            ],
          ),
        ),
        error: (error, stack) => _buildErrorState(context, ref, error),
        data: (details) {
          // Initialize selected image if not set
          _selectedImageUrl ??= details.imageUrl;
          return _buildDetailsView(context, ref, details);
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, widget.component.imageUrl),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(
                      productDetailsProvider(widget.component.id),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsView(
    BuildContext context,
    WidgetRef ref,
    ProductDetails details,
  ) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, _selectedImageUrl ?? details.imageUrl),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand
                if (details.brand != null)
                  Text(
                    details.brand!,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),

                // Title
                Text(
                  details.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Rating and Reviews
                Row(
                  children: [
                    if (details.rating != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        details.rating!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (details.reviewCount != null)
                      Text(
                        '(${details.reviewCount} reviews)',
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price', style: TextStyle(fontSize: 16)),
                      Text(
                        details.priceDisplay ??
                            '\$${details.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.greenAccent
                              : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Image Gallery - Now Interactive!
                if (details.images.isNotEmpty) ...[
                  const Text(
                    'Product Images',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap an image to view it larger',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: details.images.length,
                      itemBuilder: (context, index) {
                        final imageUrl = details.images[index];
                        final isSelected = _selectedImageUrl == imageUrl;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImageUrl = imageUrl;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.grey[700]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Description
                if (details.description != null &&
                    details.description!.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.description!,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Features
                if (details.features.isNotEmpty) ...[
                  const Text(
                    'Key Features',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...details.features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f['feature'] ?? '',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Spacer for bottom buttons
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String? imageUrl) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.image_not_supported, size: 64),
                ),
              )
            : Container(
                color: Colors.grey[900],
                child: const Icon(Icons.memory, size: 64),
              ),
      ),
    );
  }
}

class ProductDetailScreenWithActions extends ConsumerWidget {
  final Component component;

  const ProductDetailScreenWithActions({super.key, required this.component});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(productDetailsProvider(component.id));

    return Scaffold(
      body: ProductDetailScreen(component: component),
      bottomNavigationBar: detailsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (details) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = details.productUrl;
                      if (url == null || url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product link not available'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final uri = Uri.parse(url);
                      try {
                        final launched = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Amazon'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Buy on Amazon'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Create updated component with full details
                      final updatedComponent = Component(
                        id: component.id,
                        name: details.title,
                        brand: details.brand ?? component.brand,
                        type: component.type,
                        price: details.price,
                        imageUrl: details.imageUrl,
                        specs: {
                          ...component.specs,
                          'Rating': details.rating ?? 'N/A',
                          'Reviews': details.reviewCount ?? '0',
                          'ProductUrl': details.productUrl ?? '',
                        },
                      );
                      ref
                          .read(buildProvider.notifier)
                          .selectComponent(updatedComponent);
                      // Pop back to builder screen
                      Navigator.of(context)
                        ..pop()
                        ..pop();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Build'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
