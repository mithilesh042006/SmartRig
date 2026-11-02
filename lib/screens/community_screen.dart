import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component_type_ui.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicBuildsAsync = ref.watch(publicBuildsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Community Builds')),
      body: publicBuildsAsync.when(
        loading: () => const SkeletonList(
          count: 4,
          imageSize: 56,
          semanticLabel: 'Loading community builds',
        ),
        error: (error, stack) => ErrorState(
          error: error,
          title: 'Could not load community builds',
          onRetry: () => ref.invalidate(publicBuildsStreamProvider),
        ),
        data: (builds) {
          if (builds.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No community builds yet',
              message:
                  'Be the first to share. Turn on "Share with Community" when you save a build.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.xl,
            ),
            itemCount: builds.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, index) => ContentWidth(
              child: _CommunityBuildCard(savedBuild: builds[index]),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _toggleLike(
  BuildContext context,
  WidgetRef ref,
  String buildId,
) async {
  try {
    await ref.read(savedBuildsServiceProvider).toggleLike(buildId);
  } catch (e) {
    if (context.mounted) {
      showRigSnack(context, 'Could not update like: ${friendlyError(e)}');
    }
  }
}

class _LikeButton extends ConsumerWidget {
  final SavedBuild savedBuild;

  const _LikeButton({required this.savedBuild});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rig;
    final liked = ref
        .watch(savedBuildsServiceProvider)
        .hasUserLiked(savedBuild);
    final color = liked ? c.error : c.textPrimary;
    final count = savedBuild.likesCount;

    return Semantics(
      button: true,
      toggled: liked,
      label: '$count ${count == 1 ? 'like' : 'likes'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () => _toggleLike(context, ref, savedBuild.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: c.soft(color),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(liked),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: Space.xs + 2),
              Text('$count', style: context.metric(14, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityBuildCard extends StatelessWidget {
  final SavedBuild savedBuild;

  const _CommunityBuildCard({required this.savedBuild});

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BuildDetailsSheet(buildId: savedBuild.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RigCard(
      onTap: () => _showDetails(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: initialsOf(savedBuild.authorName)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedBuild.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      formatDate(savedBuild.createdAt),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(
                  color: context.rig.volt,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  formatMoney(savedBuild.totalPrice, decimals: 0),
                  style: context.metric(16, color: context.rig.onVolt),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            savedBuild.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineSmall,
          ),
          BuildHighlights(components: savedBuild.components),
          const SizedBox(height: Space.lg),
          PartStrip(components: savedBuild.components),
          const SizedBox(height: Space.md),
          Row(
            children: [
              _LikeButton(savedBuild: savedBuild),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildDetailsSheet extends ConsumerStatefulWidget {
  final String buildId;

  const _BuildDetailsSheet({required this.buildId});

  @override
  ConsumerState<_BuildDetailsSheet> createState() => _BuildDetailsSheetState();
}

class _BuildDetailsSheetState extends ConsumerState<_BuildDetailsSheet> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(savedBuildsServiceProvider);
      await service.addComment(widget.buildId, text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        showRigSnack(context, 'Could not post comment: ${friendlyError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read from the live feed so like counts update while the sheet is open.
    final builds = ref.watch(publicBuildsStreamProvider).value ?? const [];
    final matches = builds.where((build) => build.id == widget.buildId);
    if (matches.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Build not available',
          message: 'It may have been removed by its owner.',
        ),
      );
    }
    final savedBuild = matches.first;
    final commentsAsync = ref.watch(buildCommentsProvider(widget.buildId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.screen,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SheetHeader(savedBuild: savedBuild),
                    ),
                  ),
                  ...commentsAsync.when(
                    loading: () => const [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(Space.xl),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ],
                    error: (error, _) => [
                      SliverToBoxAdapter(
                        child: ErrorState(
                          error: error,
                          title: 'Could not load comments',
                          onRetry: () => ref.invalidate(
                            buildCommentsProvider(widget.buildId),
                          ),
                        ),
                      ),
                    ],
                    data: (comments) => comments.isEmpty
                        ? [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.screen,
                                  0,
                                  Space.screen,
                                  Space.xl,
                                ),
                                child: Text(
                                  'No comments yet. Start the conversation.',
                                  style: context.text.bodySmall,
                                ),
                              ),
                            ),
                          ]
                        : [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.screen,
                                0,
                                Space.screen,
                                Space.md,
                              ),
                              sliver: SliverList.separated(
                                itemCount: comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: Space.sm),
                                itemBuilder: (context, index) => _CommentTile(
                                  comment: comments[index],
                                  buildId: widget.buildId,
                                  buildOwnerId: savedBuild.userId,
                                ),
                              ),
                            ),
                          ],
                  ),
                ],
              ),
            ),
            _CommentInput(
              controller: _commentController,
              submitting: _isSubmitting,
              onSubmit: _submitComment,
            ),
          ],
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final SavedBuild savedBuild;

  const _SheetHeader({required this.savedBuild});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(savedBuild.name, style: context.text.headlineMedium),
        const SizedBox(height: Space.xs),
        Text('by ${savedBuild.authorName}', style: context.text.bodySmall),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: Text(
                formatMoney(savedBuild.totalPrice),
                style: context.metric(34, color: c.accent),
              ),
            ),
            _LikeButton(savedBuild: savedBuild),
          ],
        ),
        const SizedBox(height: Space.xl),
        Text('Parts', style: context.text.titleLarge),
        const SizedBox(height: Space.sm),
        for (final entry in savedBuild.components.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                PartTile(type: entry.key, size: 40),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key.label, style: context.text.labelSmall),
                      Text(
                        entry.value.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  entry.value.price > 0
                      ? formatMoney(entry.value.price, decimals: 0)
                      : '—',
                  style: context.metric(13),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.md),
        const Divider(),
        const SizedBox(height: Space.lg),
        Text('Comments', style: context.text.titleLarge),
        const SizedBox(height: Space.md),
      ],
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInput({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.sm,
        Space.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Write a comment...',
                  fillColor: c.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            IconButton(
              onPressed: submitting ? null : onSubmit,
              tooltip: 'Post comment',
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send, color: c.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final BuildComment comment;
  final String buildId;
  final String buildOwnerId;

  const _CommentTile({
    required this.comment,
    required this.buildId,
    required this.buildOwnerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(savedBuildsServiceProvider).currentUserId;
    // The Firestore rules let a comment's author or the build's owner delete it.
    final canDelete = comment.userId == userId || buildOwnerId == userId;

    return RigCard(
      raised: true,
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.xs,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: initialsOf(comment.userName), size: 30),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge,
                    ),
                    Text(
                      timeAgo(comment.createdAt),
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: context.rig.textSecondary,
                  tooltip: 'Delete comment',
                  onPressed: () => _deleteComment(ref, context),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: Space.md),
            child: Text(comment.text, style: context.text.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(WidgetRef ref, BuildContext context) async {
    try {
      final service = ref.read(savedBuildsServiceProvider);
      await service.deleteComment(buildId, comment.id);
    } catch (e) {
      if (context.mounted) {
        showRigSnack(context, 'Could not delete comment: ${friendlyError(e)}');
      }
    }
  }
}
