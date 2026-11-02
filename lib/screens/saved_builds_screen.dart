import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_performance.dart';
import '../widgets/rig_surfaces.dart';

class SavedBuildsScreen extends ConsumerWidget {
  const SavedBuildsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildsAsync = ref.watch(savedBuildsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Builds')),
      body: buildsAsync.when(
        loading: () => const SkeletonList(
          count: 4,
          imageSize: 56,
          semanticLabel: 'Loading saved builds',
        ),
        error: (error, stack) => ErrorState(
          error: error,
          title: 'Could not load your builds',
          onRetry: () => ref.invalidate(savedBuildsStreamProvider),
        ),
        data: (builds) {
          if (builds.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'No saved builds yet',
              message: 'Create a PC build and save it to see it here.',
              actionLabel: 'Start Building',
              onAction: () =>
                  ref.read(selectedTabProvider.notifier).select(AppTab.build),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.sm,
              Space.screen,
              Space.xl,
            ),
            itemCount: builds.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, index) =>
                ContentWidth(child: _SavedBuildCard(savedBuild: builds[index])),
          );
        },
      ),
    );
  }
}

class _SavedBuildCard extends ConsumerWidget {
  final SavedBuild savedBuild;

  const _SavedBuildCard({required this.savedBuild});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete build?',
      message: 'Are you sure you want to delete "${savedBuild.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    try {
      await ref
          .read(savedBuildsServiceProvider)
          .deleteBuild(savedBuild.id, isPublic: savedBuild.isPublic);
      // Stream auto-updates, no invalidation needed
      if (context.mounted) {
        showRigSnack(context, 'Deleted "${savedBuild.name}"');
      }
    } catch (e) {
      if (context.mounted) {
        showRigSnack(context, 'Could not delete: ${friendlyError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rig;
    final result = performanceOf(savedBuild);

    return Semantics(
      button: true,
      child: RigCard(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.xs,
          Space.lg,
        ),
        onTap: () => openSavedBuild(context, ref, savedBuild),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    savedBuild.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: c.textSecondary,
                  tooltip: 'Delete ${savedBuild.name}',
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMoney(savedBuild.totalPrice),
                    style: context.metric(24),
                  ),
                  const SizedBox(height: Space.xs),
                  BuildHighlights(components: savedBuild.components),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.xs + 2,
                    runSpacing: Space.xs + 2,
                    children: [
                      RigPill(
                        label: savedBuild.isPublic ? 'Public' : 'Private',
                        icon: savedBuild.isPublic ? Icons.public : Icons.lock,
                        color: savedBuild.isPublic ? c.success : null,
                      ),
                      if (result != null)
                        RigPill(
                          label:
                              'Est. score ${result.systemScore.toStringAsFixed(0)}',
                          icon: Icons.speed,
                          color: scoreColor(context, result.systemScore),
                        ),
                      RigPill(
                        label: savedBuild.components.length == 1
                            ? '1 part'
                            : '${savedBuild.components.length} parts',
                        icon: Icons.developer_board,
                      ),
                      RigPill(
                        label: formatDate(savedBuild.createdAt),
                        icon: Icons.calendar_today,
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
