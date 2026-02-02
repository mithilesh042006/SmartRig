import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../services/saved_builds_service.dart';
import '../providers/build_provider.dart';
import 'builder_screen.dart';

class SavedBuildsScreen extends ConsumerWidget {
  const SavedBuildsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildsAsync = ref.watch(savedBuildsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Saved Builds'), centerTitle: true),
      body: buildsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading builds: $error')),
        data: (builds) {
          if (builds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved builds yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a PC build and save it to see it here.',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: builds.length,
            itemBuilder: (context, index) {
              final build = builds[index];
              return _buildCard(context, ref, build);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, SavedBuild build) {
    final componentCount = build.components.length;
    final formattedDate = _formatDate(build.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _loadBuild(context, ref, build),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      build.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteBuild(context, ref, build),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.computer, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '$componentCount components',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Component chips
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: build.components.entries.take(4).map((entry) {
                  return Chip(
                    label: Text(
                      _getTypeShortName(entry.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: Icon(_getComponentIcon(entry.key), size: 16),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text(
                    '\$${build.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.greenAccent
                          : Colors.green[700],
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

  void _loadBuild(BuildContext context, WidgetRef ref, SavedBuild build) {
    // Load build components into the current build state
    final notifier = ref.read(buildProvider.notifier);
    notifier.clearBuild();

    for (final entry in build.components.entries) {
      notifier.selectComponent(entry.value);
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BuilderScreen()));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Loaded "${build.name}"')));
  }

  Future<void> _deleteBuild(
    BuildContext context,
    WidgetRef ref,
    SavedBuild build,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Build?'),
        content: Text('Are you sure you want to delete "${build.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(savedBuildsServiceProvider);
      await service.deleteBuild(build.id);
      // Stream auto-updates, no invalidation needed

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${build.name}"')));
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTypeShortName(ComponentType type) {
    return switch (type) {
      ComponentType.cpu => 'CPU',
      ComponentType.gpu => 'GPU',
      ComponentType.ram => 'RAM',
      ComponentType.motherboard => 'MB',
      ComponentType.storage => 'SSD',
      ComponentType.psu => 'PSU',
      ComponentType.pcCase => 'Case',
      ComponentType.cooling => 'Cool',
    };
  }

  IconData _getComponentIcon(ComponentType type) {
    return switch (type) {
      ComponentType.cpu => Icons.memory,
      ComponentType.gpu => Icons.tv,
      ComponentType.ram => Icons.storage,
      ComponentType.motherboard => Icons.developer_board,
      ComponentType.storage => Icons.sd_storage,
      ComponentType.psu => Icons.power,
      ComponentType.pcCase => Icons.computer,
      ComponentType.cooling => Icons.ac_unit,
    };
  }
}
