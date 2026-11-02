import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component_type_ui.dart';
import '../services/performance_service.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_performance.dart';
import '../widgets/rig_surfaces.dart';

class CompareBuildsScreen extends ConsumerStatefulWidget {
  const CompareBuildsScreen({super.key});

  @override
  ConsumerState<CompareBuildsScreen> createState() =>
      _CompareBuildsScreenState();
}

class _CompareBuildsScreenState extends ConsumerState<CompareBuildsScreen> {
  static const _maxBuilds = 3;

  // By ID, because the Firestore stream creates new objects on every update.
  final List<String> _selectedIds = [];
  bool _isSelecting = true;

  @override
  Widget build(BuildContext context) {
    final buildsAsync = ref.watch(savedBuildsStreamProvider);
    if (_isSelecting) return _buildSelectionScreen(buildsAsync);

    final builds = buildsAsync.value ?? const <SavedBuild>[];
    final selected = [
      for (final id in _selectedIds) ...builds.where((build) => build.id == id),
    ];
    return _buildComparisonScreen(selected);
  }

  Widget _buildSelectionScreen(AsyncValue<List<SavedBuild>> buildsAsync) {
    final enoughSelected = _selectedIds.length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Builds')),
      body: buildsAsync.when(
        loading: () => const SkeletonList(
          count: 4,
          imageSize: 40,
          semanticLabel: 'Loading saved builds',
        ),
        error: (error, stack) => ErrorState(
          error: error,
          title: 'Could not load your builds',
          onRetry: () => ref.invalidate(savedBuildsStreamProvider),
        ),
        data: (builds) {
          if (builds.isEmpty) {
            return const EmptyState(
              icon: Icons.compare_arrows,
              title: 'No builds to compare',
              message: 'Save at least two builds, then compare them here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.lg,
            ),
            itemCount: builds.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ContentWidth(
                  child: Text(
                    'Choose 2 or 3 builds. Selected: ${_selectedIds.length}/$_maxBuilds',
                    style: context.text.bodyMedium!.copyWith(
                      color: context.rig.textSecondary,
                    ),
                  ),
                );
              }
              final build = builds[index - 1];
              return ContentWidth(
                child: _SelectableBuildCard(
                  savedBuild: build,
                  selected: _selectedIds.contains(build.id),
                  onToggle: () => _toggleSelection(build),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: RigActionBar(
        child: FilledButton(
          onPressed: enoughSelected
              ? () => setState(() => _isSelecting = false)
              : null,
          child: Text(
            enoughSelected
                ? 'Compare ${_selectedIds.length} builds'
                : 'Select at least 2 builds',
          ),
        ),
      ),
    );
  }

  void _toggleSelection(SavedBuild build) {
    if (_selectedIds.contains(build.id)) {
      setState(() => _selectedIds.remove(build.id));
    } else if (_selectedIds.length < _maxBuilds) {
      setState(() => _selectedIds.add(build.id));
    } else {
      showRigSnack(context, 'Maximum $_maxBuilds builds for comparison');
    }
  }

  Widget _buildComparisonScreen(List<SavedBuild> builds) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparison'),
        leading: BackButton(
          onPressed: () => setState(() => _isSelecting = true),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.screen,
          Space.sm,
          Space.screen,
          Space.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimates, not measured results. Swipe sideways to see every build.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, build) in builds.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.md),
                        child: SizedBox(
                          width: 270,
                          child: _ComparisonCard(
                            savedBuild: build,
                            color: _bandColors[index % _bandColors.length],
                          ),
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
}

const _bandColors = [RigPalette.volt, RigPalette.tangerine, RigPalette.lilac];

class _SelectableBuildCard extends StatelessWidget {
  final SavedBuild savedBuild;
  final bool selected;
  final VoidCallback onToggle;

  const _SelectableBuildCard({
    required this.savedBuild,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      label: savedBuild.name,
      child: RigCard(
        tone: selected ? RigCardTone.selected : RigCardTone.normal,
        padding: const EdgeInsets.all(Space.md),
        onTap: onToggle,
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onToggle()),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savedBuild.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    savedBuild.components.length == 1
                        ? '1 part'
                        : '${savedBuild.components.length} parts',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              formatMoney(savedBuild.totalPrice, decimals: 0),
              style: context.metric(16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final SavedBuild savedBuild;
  final Color color;

  const _ComparisonCard({required this.savedBuild, required this.color});

  @override
  Widget build(BuildContext context) {
    final result = performanceOf(savedBuild);

    return RigCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.all(Space.lg + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  savedBuild.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge!.copyWith(
                    color: RigPalette.ink,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  formatMoney(savedBuild.totalPrice),
                  style: context.metric(30, color: RigPalette.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.lg + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result == null)
                  Text(
                    'Add a CPU and GPU to this build for performance estimates.',
                    style: context.text.bodySmall,
                  )
                else
                  _Metrics(result: result),
                const SizedBox(height: Space.md),
                const Divider(),
                const SizedBox(height: Space.md),
                Text('Parts', style: context.text.titleSmall),
                const SizedBox(height: Space.sm),
                for (final entry in savedBuild.components.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs + 2),
                    child: Row(
                      children: [
                        Icon(
                          entry.key.icon,
                          size: 16,
                          color: context.rig.textSecondary,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            entry.value.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final PerformanceResult result;

  const _Metrics({required this.result});

  @override
  Widget build(BuildContext context) {
    final (bottleneck, bottleneckColor, _) = bottleneckSummary(context, result);

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodySmall)),
          const SizedBox(width: Space.sm),
          Text(value, style: context.metric(14, color: color)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          'Est. system score',
          result.systemScore.toStringAsFixed(0),
          color: scoreColor(context, result.systemScore),
        ),
        row('CPU score', result.cpuScore.toStringAsFixed(0)),
        row('GPU score', result.gpuScore.toStringAsFixed(0)),
        const SizedBox(height: Space.sm),
        Text('Estimated FPS (1080p)', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        for (final entry in result.gameFps.entries)
          row(shortGameName(entry.key), '${entry.value.fps1080p}'),
        const SizedBox(height: Space.sm),
        Text('Power', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        row('Power draw', '${result.totalPowerW} W'),
        row('Recommended PSU', '${result.recommendedPsuW} W+'),
        const SizedBox(height: Space.sm),
        RigPill(label: bottleneck, color: bottleneckColor),
      ],
    );
  }
}
