import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../services/amazon_api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';

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

  /// True when opened from selection, where the product isn't in the build yet.
  final bool canAddToBuild;

  const ProductDetailScreen({
    super.key,
    required this.component,
    this.canAddToBuild = false,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _selectedImageUrl;

  Future<void> _openOnAmazon(ProductDetails? details) async {
    final url =
        details?.productUrl ?? widget.component.specs['ProductUrl'] as String?;
    if (url == null || url.isEmpty) {
      showRigSnack(context, 'Product link not available');
      return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) showRigSnack(context, 'Could not open Amazon');
    } catch (_) {
      if (mounted) showRigSnack(context, 'Could not open Amazon');
    }
  }

  void _addToBuild(ProductDetails? details) {
    final component = widget.component;
    // Details can lack a field the search result had, so keep what's known.
    final updated = details == null
        ? component
        : Component(
            id: component.id,
            name: details.title,
            brand: details.brand ?? component.brand,
            type: component.type,
            price: details.price > 0 ? details.price : component.price,
            imageUrl: details.imageUrl ?? component.imageUrl,
            specs: {
              ...component.specs,
              'Rating': details.rating ?? component.specs['Rating'] ?? 'N/A',
              'Reviews':
                  details.reviewCount ?? component.specs['Reviews'] ?? '0',
              'ProductUrl':
                  details.productUrl ?? component.specs['ProductUrl'] ?? '',
            },
          );
    ref.read(buildProvider.notifier).selectComponent(updated);
    // Back past the selection screen to the builder.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = productDetailsProvider(widget.component.id);
    final detailsAsync = ref.watch(provider);
    final details = detailsAsync.value;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _GalleryHeader(
            imageUrl:
                _selectedImageUrl ??
                details?.imageUrl ??
                widget.component.imageUrl,
            fallbackIcon: widget.component.type.icon,
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.all(Space.screen),
                child: detailsAsync.when(
                  loading: () => _ProductSummary(
                    title: widget.component.name,
                    price: widget.component.price,
                    footer: const Padding(
                      padding: EdgeInsets.only(top: Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 120, height: 18),
                          SizedBox(height: Space.md),
                          Skeleton(),
                          SizedBox(height: Space.sm),
                          Skeleton(),
                          SizedBox(height: Space.sm),
                          Skeleton(width: 200),
                        ],
                      ),
                    ),
                  ),
                  error: (error, _) => _ProductSummary(
                    title: widget.component.name,
                    price: widget.component.price,
                    footer: ErrorState(
                      error: error,
                      title: 'Could not load the full details',
                      onRetry: () => ref.invalidate(provider),
                    ),
                  ),
                  data: (details) => _ProductSummary(
                    title: details.title,
                    brand: details.brand,
                    rating: details.rating,
                    reviewCount: details.reviewCount,
                    priceDisplay: details.priceDisplay,
                    price: details.price > 0
                        ? details.price
                        : widget.component.price,
                    footer: _DetailsBody(
                      details: details,
                      selectedImageUrl: _selectedImageUrl ?? details.imageUrl,
                      onSelectImage: (url) =>
                          setState(() => _selectedImageUrl = url),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: RigActionBar(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openOnAmazon(details),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Buy on Amazon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (widget.canAddToBuild) ...[
              const SizedBox(width: Space.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => _addToBuild(details),
                  child: const Text(
                    'Add to Build',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  final String? imageUrl;
  final IconData fallbackIcon;

  const _GalleryHeader({required this.imageUrl, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: c.background,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(Space.xs + 2),
        child: IconButton.filledTonal(
          tooltip: 'Back',
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            foregroundColor: c.textPrimary,
          ),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ProductImage(url: imageUrl, fallbackIcon: fallbackIcon),
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  final String title;
  final String? brand;
  final String? rating;
  final String? reviewCount;
  final String? priceDisplay;
  final double price;
  final Widget footer;

  const _ProductSummary({
    required this.title,
    required this.price,
    required this.footer,
    this.brand,
    this.rating,
    this.reviewCount,
    this.priceDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand != null && brand!.isNotEmpty) ...[
          RigPill(label: brand!, color: c.accent),
          const SizedBox(height: Space.sm),
        ],
        Text(title, style: context.text.headlineSmall),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                priceDisplay ?? formatPrice(price),
                style: price > 0 || priceDisplay != null
                    ? context.metric(40)
                    : context.text.bodyMedium,
              ),
            ),
            if (rating != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(
                  color: RigPalette.sun,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: RigPalette.ink),
                    const SizedBox(width: Space.xs),
                    Text(
                      rating!,
                      style: context.metric(14, color: RigPalette.ink),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (reviewCount != null) ...[
          const SizedBox(height: Space.xs),
          Text('$reviewCount reviews', style: context.text.bodySmall),
        ],
        footer,
      ],
    );
  }
}

class _DetailsBody extends StatelessWidget {
  final ProductDetails details;
  final String? selectedImageUrl;
  final ValueChanged<String> onSelectImage;

  const _DetailsBody({
    required this.details,
    required this.selectedImageUrl,
    required this.onSelectImage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final description = details.description;
    final features = details.features
        .map((f) => f['feature'] ?? '')
        .where((f) => f.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.images.length > 1) ...[
          const SizedBox(height: Space.xl),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: details.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, index) {
                final url = details.images[index];
                final selected = selectedImageUrl == url;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Product image ${index + 1}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onSelectImage(url),
                    child: AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: selected ? c.textPrimary : c.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ProductImage(url: url, size: 72),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: Space.xxl),
          const SectionHeader(title: 'Description'),
          Text(
            description,
            style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
          ),
        ],
        if (features.isNotEmpty) ...[
          const SizedBox(height: Space.xxl),
          const SectionHeader(title: 'Key features'),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 20, color: c.success),
                  const SizedBox(width: Space.sm + 2),
                  Expanded(
                    child: Text(feature, style: context.text.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
