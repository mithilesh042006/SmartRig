import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';
import '../services/performance_service.dart';
import '../services/saved_builds_service.dart';

// Performance service provider
final performanceServiceProvider = Provider((ref) => PerformanceService());

// Performance result provider
final performanceResultProvider = Provider<PerformanceResult?>((ref) {
  final buildState = ref.watch(buildProvider);
  final service = ref.watch(performanceServiceProvider);
  return service.calculatePerformance(buildState);
});

class ReviewBuildScreen extends ConsumerWidget {
  const ReviewBuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(performanceResultProvider);
    final buildState = ref.watch(buildProvider);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Build')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 64, color: Colors.amber),
                SizedBox(height: 16),
                Text(
                  'Please select at least a CPU and GPU to see performance predictions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Review'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall System Score
            _buildSystemScoreCard(result),
            const SizedBox(height: 16),

            // CPU & GPU Cards
            Row(
              children: [
                Expanded(
                  child: _buildComponentCard(
                    'CPU',
                    result.cpuScore,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildComponentCard(
                    'GPU',
                    result.gpuScore,
                    Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // FPS Predictions
            _buildSectionTitle('Gaming FPS Predictions'),
            const SizedBox(height: 12),
            _buildFpsChart(result),
            const SizedBox(height: 24),

            // Power & PSU
            _buildSectionTitle('Power Consumption'),
            const SizedBox(height: 12),
            _buildPowerCard(result),
            const SizedBox(height: 24),

            // Bottleneck Analysis
            _buildSectionTitle('Bottleneck Analysis'),
            const SizedBox(height: 12),
            _buildBottleneckCard(context, result),
            const SizedBox(height: 24),

            // Components Summary
            _buildSectionTitle('Build Summary'),
            const SizedBox(height: 12),
            _buildComponentsList(context, buildState),
            const SizedBox(height: 24),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Performance results are estimates and may vary based on cooling, drivers, workload, and system configuration.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaveDialog(context, ref, buildState),
        icon: const Icon(Icons.save),
        label: const Text('Save Build'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  void _showSaveDialog(BuildContext context, WidgetRef ref, BuildState state) {
    final controller = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Build'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Build Name',
                  hintText: 'e.g., Gaming Beast, Budget Build',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Public/Private toggle
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('Share with Community'),
                  subtitle: Text(
                    isPublic
                        ? 'Everyone can see this build'
                        : 'Only you can see this build',
                    style: TextStyle(
                      color: isPublic ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  value: isPublic,
                  onChanged: (value) {
                    setDialogState(() => isPublic = value);
                  },
                  secondary: Icon(
                    isPublic ? Icons.public : Icons.lock,
                    color: isPublic ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                try {
                  final service = ref.read(savedBuildsServiceProvider);

                  // Check if user is authenticated
                  if (service.currentUserId == null) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please login to save builds'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final components = <ComponentType, Component>{};
                  state.selectedComponents.forEach((key, value) {
                    if (value != null) {
                      components[key] = value;
                    }
                  });

                  final build = SavedBuild(
                    id: service.generateId(),
                    name: name,
                    components: components,
                    totalPrice: state.totalPrice,
                    createdAt: DateTime.now(),
                    userId: service.currentUserId!,
                    isPublic: isPublic,
                    authorName: service.currentUserName,
                  );

                  await service.addBuild(build);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    final message = isPublic
                        ? 'Saved "$name" and shared with community!'
                        : 'Saved "$name"';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Error saving build: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSystemScoreCard(PerformanceResult result) {
    final normalizedScore = (result.systemScore / 40000).clamp(0.0, 1.0);
    final scoreLabel = _getScoreLabel(result.systemScore);

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Overall System Score',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              CircularPercentIndicator(
                radius: 80,
                lineWidth: 12,
                percent: normalizedScore,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.systemScore.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getScoreColor(result.systemScore),
                      ),
                    ),
                  ],
                ),
                progressColor: _getScoreColor(result.systemScore),
                backgroundColor: Colors.grey[800]!,
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentCard(String label, double score, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(_getScoreLabel(score), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFpsChart(PerformanceResult result) {
    final games = result.gameFps.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('1080p', Colors.greenAccent),
                const SizedBox(width: 16),
                _buildLegendItem('1440p', Colors.blueAccent),
                const SizedBox(width: 16),
                _buildLegendItem('4K', Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 16),
            // Chart
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 200,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < games.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                games[value.toInt()].key.split(' ').first,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 32,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey[800]!, strokeWidth: 1),
                  ),
                  barGroups: games.asMap().entries.map((entry) {
                    final fps = entry.value.value;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: fps.fps1080p.toDouble(),
                          color: Colors.greenAccent,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: fps.fps1440p.toDouble(),
                          color: Colors.blueAccent,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: fps.fps4k.toDouble(),
                          color: Colors.purpleAccent,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPowerCard(PerformanceResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated Power Draw'),
                Text(
                  '${result.totalPowerW}W',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recommended PSU'),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${result.recommendedPsuW}W+',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleneckCard(BuildContext context, PerformanceResult result) {
    final (icon, color, message) = switch (result.bottleneck) {
      BottleneckType.cpu => (
        Icons.memory,
        Colors.orange,
        'CPU Bottleneck (${result.bottleneckPercentage.toStringAsFixed(0)}%)',
      ),
      BottleneckType.gpu => (
        Icons.tv,
        Colors.orange,
        'GPU Bottleneck (${result.bottleneckPercentage.toStringAsFixed(0)}%)',
      ),
      BottleneckType.balanced => (
        Icons.check_circle,
        Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green[700]!,
        'Balanced System - No significant bottleneck detected',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 16, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentsList(BuildContext context, BuildState state) {
    final components = state.selectedComponents.entries
        .where((e) => e.value != null)
        .toList();

    return Card(
      child: Column(
        children: components.map((entry) {
          final component = entry.value!;
          return ListTile(
            leading: Icon(_getComponentIcon(entry.key)),
            title: Text(
              component.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              component.priceFormatted,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.greenAccent
                    : Colors.green[700],
              ),
            ),
          );
        }).toList(),
      ),
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

  String _getScoreLabel(double score) {
    if (score >= 35000) return 'Extreme';
    if (score >= 28000) return 'Enthusiast';
    if (score >= 20000) return 'High-End';
    if (score >= 15000) return 'Mid-Range';
    if (score >= 10000) return 'Entry';
    return 'Budget';
  }

  Color _getScoreColor(double score) {
    if (score >= 35000) return Colors.purpleAccent;
    if (score >= 28000) return Colors.blueAccent;
    if (score >= 20000) return Colors.green;
    if (score >= 15000) return Colors.amber;
    if (score >= 10000) return Colors.orange;
    return Colors.redAccent;
  }
}
