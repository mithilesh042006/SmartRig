import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';
import 'component_selection_screen.dart';
import 'review_build_screen.dart';
import 'product_detail_screen.dart';
import 'build_3d_viewer_screen.dart';

class BuilderScreen extends ConsumerWidget {
  const BuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState = ref.watch(buildProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom PC Build'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(buildProvider.notifier).clearBuild();
            },
            tooltip: 'Clear Build',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSlot(
                  context,
                  ref,
                  ComponentType.cpu,
                  'CPU',
                  Icons.memory,
                ),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.motherboard,
                  'Motherboard',
                  Icons.developer_board,
                ),
                _buildSlot(context, ref, ComponentType.gpu, 'GPU', Icons.tv),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.ram,
                  'RAM',
                  Icons.storage,
                ),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.storage,
                  'Storage',
                  Icons.sd_storage,
                ),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.psu,
                  'Power Supply',
                  Icons.power,
                ),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.pcCase,
                  'Case',
                  Icons.computer,
                ),
                _buildSlot(
                  context,
                  ref,
                  ComponentType.cooling,
                  'Cooling',
                  Icons.ac_unit,
                ),
              ],
            ),
          ),
          _buildSummary(context, buildState),
        ],
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    WidgetRef ref,
    ComponentType type,
    String label,
    IconData icon,
  ) {
    final buildState = ref.watch(buildProvider);
    final selectedComponent = buildState.selectedComponents[type];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Icon(icon, color: Colors.blueAccent),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          selectedComponent?.name ?? 'Not Selected',
          style: TextStyle(
            color: selectedComponent != null
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Colors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: selectedComponent != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedComponent.priceFormatted,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.greenAccent
                          : Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Change component',
                    onPressed: () => _navigateToSelection(context, type),
                  ),
                ],
              )
            : const Icon(Icons.add_circle_outline),
        onTap: () {
          if (selectedComponent != null) {
            // Navigate to product detail screen for viewing
            _navigateToProductDetail(context, selectedComponent);
          } else {
            // Navigate to component selection screen
            _navigateToSelection(context, type);
          }
        },
      ),
    );
  }

  void _navigateToSelection(BuildContext context, ComponentType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComponentSelectionScreen(componentType: type),
      ),
    );
  }

  void _navigateToProductDetail(BuildContext context, Component component) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(component: component),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, BuildState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Estimate',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  '\$${state.totalPrice.toStringAsFixed(2)}',
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.totalPrice > 0
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ReviewBuildScreen(),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Review Build'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const Build3DViewerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.view_in_ar),
                label: const Text('View 3D Build'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
