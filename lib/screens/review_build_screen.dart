import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../services/compatibility_service.dart';
import '../services/performance_service.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/compatibility_card.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_performance.dart';
import '../widgets/rig_surfaces.dart';

// Performance service provider
final performanceServiceProvider = Provider(
  (ref) => const PerformanceService(),
);

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
    final c = context.rig;
    const gridGap = SizedBox(width: Space.sm + 2);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Build')),
        body: EmptyState(
          icon: Icons.speed,
          title: 'Add a CPU and GPU',
          message:
              'Please select at least a CPU and GPU to see performance predictions.',
          actionLabel: 'Back to build',
          onAction: () => Navigator.maybePop(context),
        ),
      );
    }

    final (bottleneckLabel, bottleneckColor, bottleneckIcon) =
        bottleneckSummary(context, result);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.xxl,
        ),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScoreCard(result: result),
              const SizedBox(height: Space.md),
              CompatibilityCard(report: ref.watch(compatibilityProvider)),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ComponentScoreCard(
                        label: 'CPU',
                        icon: ComponentType.cpu.icon,
                        score: result.cpuScore,
                        color: ComponentType.cpu.tint,
                      ),
                    ),
                    gridGap,
                    Expanded(
                      child: ComponentScoreCard(
                        label: 'GPU',
                        icon: ComponentType.gpu.icon,
                        score: result.gpuScore,
                        color: ComponentType.gpu.tint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Estimated Gaming FPS'),
              if (result.isApproximate) ...[
                Text(
                  _approximateMessage(result),
                  style: context.text.bodyMedium!.copyWith(color: c.warning),
                ),
                const SizedBox(height: Space.md),
              ],
              RigInkCard(
                child: Column(
                  children: [
                    const FpsLegend(),
                    const SizedBox(height: Space.lg),
                    FpsChart(gameFps: result.gameFps),
                    const SizedBox(height: Space.lg),
                    FpsTable(gameFps: result.gameFps),
                  ],
                ),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Power'),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MetricTile(
                        icon: Icons.bolt,
                        label: 'Estimated power draw',
                        value: '${result.totalPowerW} W',
                        color: RigPalette.sun,
                      ),
                    ),
                    gridGap,
                    Expanded(
                      child: MetricTile(
                        icon: ComponentType.psu.icon,
                        label: 'Recommended PSU',
                        value: '${result.recommendedPsuW} W+',
                        color: ComponentType.psu.tint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Balance'),
              RigCard(
                child: Row(
                  children: [
                    RigIconBox(icon: bottleneckIcon, color: bottleneckColor),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bottleneckLabel,
                            style: context.text.titleSmall!.copyWith(
                              color: bottleneckColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.bottleneck == BottleneckType.balanced
                                ? 'No significant bottleneck detected.'
                                : 'One part is well ahead of the other in our index.',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Build summary'),
              _BuildSummary(state: buildState),
              const SizedBox(height: Space.xl),
              RigCard(
                raised: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: c.textSecondary, size: 20),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        'Scores and FPS are rough estimates from our own gaming index, not measured benchmarks. They assume high settings without upscaling or ray tracing. Real results vary by game, drivers, cooling and settings, so use them to compare builds.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: RigActionBar(
        child: FilledButton.icon(
          onPressed: () => _showSaveDialog(context, ref, buildState),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save Build'),
        ),
      ),
    );
  }

  String _approximateMessage(PerformanceResult result) {
    final part = !result.cpuInIndex && !result.gpuInIndex
        ? 'this CPU and GPU'
        : !result.cpuInIndex
        ? 'this CPU'
        : 'this GPU';
    return 'We have no performance data for $part yet, so these numbers are especially approximate.';
  }

  void _showSaveDialog(BuildContext context, WidgetRef ref, BuildState state) {
    final controller = TextEditingController();
    bool isPublic = false;
    final problems = ref
        .read(compatibilityProvider)
        .count(CompatibilityStatus.incompatible);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final c = context.rig;
          return AlertDialog(
            title: const Text('Save Build'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (problems > 0) ...[
                    Text(
                      problems == 1
                          ? 'This build has a compatibility problem. You can still save it.'
                          : 'This build has $problems compatibility problems. You can still save it.',
                      style: context.text.bodyMedium!.copyWith(color: c.error),
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Build name',
                      hintText: 'e.g., Gaming Beast, Budget Build',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Share with Community',
                      style: context.text.titleSmall,
                    ),
                    subtitle: Text(
                      isPublic
                          ? 'Everyone can see this build'
                          : 'Only you can see this build',
                      style: context.text.bodySmall,
                    ),
                    value: isPublic,
                    onChanged: (value) {
                      setDialogState(() => isPublic = value);
                    },
                  ),
                ],
              ),
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
                    showRigSnack(dialogContext, 'Please enter a name');
                    return;
                  }

                  try {
                    final service = ref.read(savedBuildsServiceProvider);

                    // Check if user is authenticated
                    if (service.currentUserId == null) {
                      if (dialogContext.mounted) {
                        showRigSnack(
                          dialogContext,
                          'Please login to save builds',
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
                      final messenger = ScaffoldMessenger.of(dialogContext);
                      Navigator.pop(dialogContext);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isPublic
                                ? 'Saved "$name" and shared with community!'
                                : 'Saved "$name"',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      showRigSnack(
                        dialogContext,
                        'Error saving build: ${friendlyError(e)}',
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final PerformanceResult result;

  const _ScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.systemScore;
    final tier = ScoreTier.fromScore(score).label;

    return RigInkCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Builder(
        builder: (context) {
          final c = context.rig;
          return Column(
            children: [
              Text(
                'Estimated System Score',
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Space.lg),
              RigGauge(
                progress: score / 200,
                color: c.volt,
                semanticLabel:
                    'Estimated system score ${score.toStringAsFixed(0)}, $tier',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(score.toStringAsFixed(0), style: context.metric(56)),
                    const SizedBox(height: Space.xs),
                    RigPill(label: tier, color: c.volt),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                'Our gaming index: 100 is about a Core i9-12900K with an RTX 3080.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BuildSummary extends StatelessWidget {
  final BuildState state;

  const _BuildSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final components = state.selectedComponents.entries
        .where((e) => e.value != null)
        .toList();

    return RigCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        children: [
          for (final entry in components)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Row(
                children: [
                  PartThumbnail(component: entry.value!),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key.label, style: context.text.labelSmall),
                        Text(
                          entry.value!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    entry.value!.price > 0
                        ? formatMoney(entry.value!.price)
                        : '—',
                    style: context.metric(13),
                  ),
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Row(
              children: [
                Expanded(child: Text('Total', style: context.text.titleSmall)),
                Text(
                  formatMoney(state.totalPrice),
                  style: context.metric(22, color: context.rig.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
