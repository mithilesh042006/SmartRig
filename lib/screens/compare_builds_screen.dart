import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';
import '../services/saved_builds_service.dart';
import '../services/performance_service.dart';

class CompareBuildsScreen extends ConsumerStatefulWidget {
  const CompareBuildsScreen({super.key});

  @override
  ConsumerState<CompareBuildsScreen> createState() =>
      _CompareBuildsScreenState();
}

class _CompareBuildsScreenState extends ConsumerState<CompareBuildsScreen> {
  final List<SavedBuild> _selectedBuilds = [];
  bool _isSelecting = true;

  @override
  Widget build(BuildContext context) {
    if (_isSelecting) {
      return _buildSelectionScreen();
    }
    return _buildComparisonScreen();
  }

  Widget _buildSelectionScreen() {
    final buildsAsync = ref.watch(savedBuildsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Builds to Compare'),
        actions: [
          if (_selectedBuilds.length >= 2)
            TextButton(
              onPressed: () => setState(() => _isSelecting = false),
              child: const Text('Compare'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueAccent.withAlpha(30),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected: ${_selectedBuilds.length}/3 builds',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          Expanded(
            child: buildsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (builds) {
                if (builds.isEmpty) {
                  return const Center(
                    child: Text(
                      'No saved builds to compare.\nSave some builds first!',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: builds.length,
                  itemBuilder: (context, index) {
                    final build = builds[index];
                    final isSelected = _selectedBuilds.contains(build);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected
                          ? Colors.blueAccent.withAlpha(50)
                          : null,
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(build),
                        ),
                        title: Text(build.name),
                        subtitle: Text(
                          '\$${build.totalPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text('${build.components.length} parts'),
                        onTap: () => _toggleSelection(build),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(SavedBuild build) {
    setState(() {
      if (_selectedBuilds.contains(build)) {
        _selectedBuilds.remove(build);
      } else if (_selectedBuilds.length < 3) {
        _selectedBuilds.add(build);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 builds for comparison')),
        );
      }
    });
  }

  Widget _buildComparisonScreen() {
    final service = PerformanceService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Builds'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _isSelecting = true),
        ),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _selectedBuilds.map((build) {
              // Convert SavedBuild to BuildState for performance calculation
              final buildState = BuildState(
                selectedComponents: build.components.map(
                  (key, value) => MapEntry(key, value),
                ),
              );
              final result = service.calculatePerformance(buildState);

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: _buildComparisonCard(build, result),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonCard(SavedBuild build, PerformanceResult? result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Build name
            Text(
              build.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),

            // Total Price
            _buildMetricRow(
              'Total Price',
              '\$${build.totalPrice.toStringAsFixed(2)}',
              Colors.greenAccent,
            ),
            const SizedBox(height: 16),

            if (result != null) ...[
              // System Score
              _buildMetricRow(
                'System Score',
                result.systemScore.toStringAsFixed(0),
                Colors.blueAccent,
              ),
              const SizedBox(height: 8),

              // CPU Score
              _buildMetricRow(
                'CPU Score',
                result.cpuScore.toStringAsFixed(0),
                Colors.cyan,
              ),
              const SizedBox(height: 8),

              // GPU Score
              _buildMetricRow(
                'GPU Score',
                result.gpuScore.toStringAsFixed(0),
                Colors.purple,
              ),
              const SizedBox(height: 16),

              // FPS Section
              const Text(
                'Gaming FPS (1080p)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.gameFps.entries
                  .take(3)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              e.key.split(' ').first,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value.fps1080p} FPS',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),

              // Power
              _buildMetricRow(
                'Power Draw',
                '${result.totalPowerW}W',
                Colors.amber,
              ),
              const SizedBox(height: 8),
              _buildMetricRow(
                'Rec. PSU',
                '${result.recommendedPsuW}W+',
                Colors.orange,
              ),
              const SizedBox(height: 16),

              // Bottleneck
              _buildBottleneckChip(result),
            ] else
              const Text(
                'Add CPU & GPU for performance data',
                style: TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Components list
            const Text(
              'Components',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...build.components.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      _getComponentIcon(e.key),
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildBottleneckChip(PerformanceResult result) {
    final (label, color) = switch (result.bottleneck) {
      BottleneckType.cpu => ('CPU Bottleneck', Colors.orange),
      BottleneckType.gpu => ('GPU Bottleneck', Colors.orange),
      BottleneckType.balanced => ('Balanced', Colors.greenAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
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
