import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';
import 'product_detail_screen.dart';

/// Predefined brands and models for each component type
class ComponentOptions {
  static Map<String, List<String>> getBrandsAndModels(ComponentType type) {
    switch (type) {
      case ComponentType.cpu:
        return {
          'Intel': ['Core i3', 'Core i5', 'Core i7', 'Core i9', 'Xeon'],
          'AMD': ['Ryzen 3', 'Ryzen 5', 'Ryzen 7', 'Ryzen 9', 'Threadripper'],
        };
      case ComponentType.gpu:
        return {
          'NVIDIA': [
            'RTX 4090',
            'RTX 4080',
            'RTX 4070',
            'RTX 4060',
            'RTX 3080',
            'RTX 3070',
            'RTX 3060',
          ],
          'AMD': [
            'RX 7900 XTX',
            'RX 7900 XT',
            'RX 7800 XT',
            'RX 7700 XT',
            'RX 6800 XT',
            'RX 6700 XT',
          ],
          'Intel': ['Arc A770', 'Arc A750', 'Arc A580'],
        };
      case ComponentType.ram:
        return {
          'Corsair': [
            'Vengeance DDR5',
            'Vengeance DDR4',
            'Dominator DDR5',
            'Dominator DDR4',
          ],
          'G.Skill': [
            'Trident Z5 DDR5',
            'Trident Z DDR4',
            'Ripjaws DDR5',
            'Ripjaws DDR4',
          ],
          'Kingston': ['Fury Beast DDR5', 'Fury Beast DDR4', 'Fury Renegade'],
          'Crucial': ['Ballistix DDR4', 'Pro DDR5'],
        };
      case ComponentType.motherboard:
        return {
          'ASUS': ['ROG Strix', 'TUF Gaming', 'Prime', 'ProArt'],
          'MSI': ['MEG', 'MPG', 'MAG', 'PRO'],
          'Gigabyte': ['AORUS Master', 'AORUS Pro', 'Gaming X', 'UD'],
          'ASRock': ['Taichi', 'Steel Legend', 'Phantom Gaming', 'Pro'],
        };
      case ComponentType.storage:
        return {
          'Samsung': [
            '990 Pro NVMe',
            '980 Pro NVMe',
            '970 Evo Plus',
            '870 Evo SSD',
          ],
          'Western Digital': [
            'Black SN850X',
            'Black SN770',
            'Blue SN580',
            'Blue SATA SSD',
          ],
          'Seagate': ['FireCuda 530', 'BarraCuda SSD', 'IronWolf NAS'],
          'Crucial': ['P5 Plus NVMe', 'MX500 SSD', 'BX500 SSD'],
        };
      case ComponentType.psu:
        return {
          'Corsair': ['RM850x', 'RM750x', 'HX1000', 'SF750'],
          'EVGA': ['SuperNOVA 850', 'SuperNOVA 750', 'SuperNOVA 650'],
          'Seasonic': ['Prime TX-850', 'Focus GX-750', 'Focus PX-650'],
          'be quiet!': ['Dark Power 12', 'Straight Power 11', 'Pure Power 11'],
        };
      case ComponentType.pcCase:
        return {
          'NZXT': ['H7 Flow', 'H5 Flow', 'H9 Elite', 'H510'],
          'Corsair': ['4000D Airflow', '5000D Airflow', 'iCUE 5000X', '275R'],
          'Lian Li': ['O11 Dynamic', 'Lancool III', 'A4-H2O'],
          'Fractal Design': ['Torrent', 'North', 'Meshify 2', 'Define 7'],
        };
      case ComponentType.cooling:
        return {
          'Noctua': ['NH-D15', 'NH-U12S', 'NH-L9i', 'NH-U9S'],
          'Corsair': ['iCUE H150i', 'iCUE H100i', 'iCUE H170i'],
          'NZXT': ['Kraken X73', 'Kraken X63', 'Kraken Z73', 'Kraken X53'],
          'be quiet!': ['Dark Rock Pro 4', 'Dark Rock 4', 'Pure Rock 2'],
          'Cooler Master': [
            'Hyper 212',
            'MasterLiquid ML360',
            'MasterAir MA624',
          ],
        };
    }
  }
}

class ComponentSelectionScreen extends ConsumerStatefulWidget {
  final ComponentType componentType;

  const ComponentSelectionScreen({super.key, required this.componentType});

  @override
  ConsumerState<ComponentSelectionScreen> createState() =>
      _ComponentSelectionScreenState();
}

class _ComponentSelectionScreenState
    extends ConsumerState<ComponentSelectionScreen> {
  final _searchController = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  String _searchQuery = '';

  late Map<String, List<String>> _brandsAndModels;

  @override
  void initState() {
    super.initState();
    _brandsAndModels = ComponentOptions.getBrandsAndModels(
      widget.componentType,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Searches run on submit, not per keystroke: each one spends RapidAPI quota.
  void _submitSearch(String text) {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _searchQuery = text.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _submitSearch('');
  }

  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = _selectedBrand == brand ? null : brand;
      _selectedModel = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _selectModel(String model) {
    setState(() {
      final deselect = _selectedModel == model;
      _selectedModel = deselect ? null : model;
      _searchQuery = deselect ? '' : '$_selectedBrand $model';
    });
  }

  void _addToBuild(Component component) {
    ref.read(buildProvider.notifier).selectComponent(component);
    Navigator.pop(context);
    showRigSnack(context, 'Added ${component.name} to your build');
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.componentType.label;

    return Scaffold(
      appBar: AppBar(title: Text('Choose $label')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.screen,
                Space.xs,
                Space.screen,
                Space.md,
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  hintText: 'Search by name or model',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _searchController,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
            ),
          ),
          _ChipRow(
            label: 'Brand',
            options: _brandsAndModels.keys.toList(),
            selected: _selectedBrand,
            onSelect: _selectBrand,
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.normal),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _selectedBrand == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: _ChipRow(
                      label: 'Model',
                      options: _brandsAndModels[_selectedBrand]!,
                      selected: _selectedModel,
                      onSelect: _selectModel,
                    ),
                  ),
          ),
          const SizedBox(height: Space.sm),
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final provider = componentsProvider((
      type: widget.componentType,
      query: _searchQuery,
    ));
    final componentsAsync = ref.watch(provider);

    return componentsAsync.when(
      loading: () => const SkeletonList(semanticLabel: 'Loading products'),
      error: (error, stack) => ErrorState(
        error: error,
        title: 'Could not load products',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (components) => components.isEmpty
          ? EmptyState(
              icon: Icons.search_off,
              title: 'No products found',
              message: _searchQuery.isEmpty
                  ? 'Amazon returned no products for this category.'
                  : 'Try a different brand, model, or search.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Space.screen),
              itemCount: components.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, index) => ContentWidth(
                child: _ProductCard(
                  component: components[index],
                  onAdd: () => _addToBuild(components[index]),
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        component: components[index],
                        canAddToBuild: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ChipRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Semantics(
      label: '$label filter',
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: Row(
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: ChoiceChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: (_) => onSelect(option),
                  labelStyle: context.text.labelLarge!.copyWith(
                    color: selected == option ? c.onVolt : c.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Component component;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  const _ProductCard({
    required this.component,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final rating = component.specs['Rating'];
    final reviews = component.specs['Reviews'];
    final hasRating = rating != null && rating != 'N/A' && rating != '';
    final hasReviews = reviews != null && reviews != '0' && reviews != '';

    return Semantics(
      button: true,
      child: RigCard(
        padding: const EdgeInsets.all(Space.sm + 2),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: SizedBox(
                height: 176,
                child: ProductImage(
                  url: component.imageUrl,
                  fallbackIcon: component.type.icon,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.md,
                Space.sm,
                Space.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    component.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  if (hasRating || hasReviews) ...[
                    const SizedBox(height: Space.xs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.xs,
                      children: [
                        if (hasRating) ...[
                          Icon(Icons.star, size: 15, color: c.accent),
                          Text('$rating', style: context.text.labelMedium),
                        ],
                        if (hasReviews)
                          Text(
                            '($reviews reviews)',
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatPrice(component.price),
                          style: component.price > 0
                              ? context.metric(26)
                              : context.text.bodySmall,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: onAdd,
                        tooltip: 'Add ${component.name} to build',
                        style: IconButton.styleFrom(
                          backgroundColor: c.volt,
                          foregroundColor: c.onVolt,
                          minimumSize: const Size(52, 52),
                        ),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
