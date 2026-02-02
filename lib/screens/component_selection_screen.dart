import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';
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

  void _performSearch() {
    if (_selectedBrand != null && _selectedModel != null) {
      setState(() {
        _searchQuery = '$_selectedBrand $_selectedModel';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${_getTypeLabel(widget.componentType)}'),
      ),
      body: Column(
        children: [
          // Selection area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Brand Selection
                const Text(
                  'Select Brand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _brandsAndModels.keys.map((brand) {
                    final isSelected = _selectedBrand == brand;
                    return ChoiceChip(
                      label: Text(brand),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedBrand = selected ? brand : null;
                          _selectedModel = null;
                          _searchQuery = ''; // Reset to default search
                        });
                      },
                      selectedColor: Colors.blueAccent,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),

                // Step 2: Model Selection (only show if brand selected)
                if (_selectedBrand != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Select Model',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _brandsAndModels[_selectedBrand]!.map((model) {
                      final isSelected = _selectedModel == model;
                      return ChoiceChip(
                        label: Text(model),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedModel = selected ? model : null;
                          });
                          if (selected) {
                            _performSearch();
                          } else {
                            setState(() => _searchQuery = '');
                          }
                        },
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Selected info
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Searching: $_searchQuery',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Product list
          Expanded(child: _buildProductList()),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final componentsAsync = ref.watch(
      componentsProvider((type: widget.componentType, query: _searchQuery)),
    );

    return componentsAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching products from Amazon...'),
          ],
        ),
      ),
      error: (error, stack) => Center(
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
                  componentsProvider((
                    type: widget.componentType,
                    query: _searchQuery,
                  )),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (components) => components.isEmpty
          ? const Center(child: Text('No products found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: components.length,
              itemBuilder: (context, index) {
                final component = components[index];
                return _buildProductCard(component);
              },
            ),
    );
  }

  Widget _buildProductCard(Component component) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailScreenWithActions(component: component),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: component.imageUrl != null
                    ? Image.network(
                        component.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.memory),
                      ),
              ),
              const SizedBox(width: 12),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.brand,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (component.specs['Rating'] != null &&
                            component.specs['Rating'] != 'N/A')
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${component.specs['Rating']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        Text(
                          '${component.specs['Reviews']} reviews',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Price and add button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    component.priceFormatted,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.greenAccent
                          : Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      ref
                          .read(buildProvider.notifier)
                          .selectComponent(component);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${component.name} to build'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(ComponentType type) {
    switch (type) {
      case ComponentType.cpu:
        return 'CPU';
      case ComponentType.gpu:
        return 'GPU';
      case ComponentType.ram:
        return 'RAM';
      case ComponentType.motherboard:
        return 'Motherboard';
      case ComponentType.storage:
        return 'Storage';
      case ComponentType.psu:
        return 'Power Supply';
      case ComponentType.pcCase:
        return 'Case';
      case ComponentType.cooling:
        return 'Cooling';
    }
  }
}
