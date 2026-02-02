import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/saved_builds_service.dart';
import '../models/component.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicBuildsAsync = ref.watch(publicBuildsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Community Builds'), centerTitle: true),
      body: publicBuildsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (builds) {
          if (builds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  const Text(
                    'No community builds yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share your build!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: builds.length,
            itemBuilder: (context, index) {
              final savedBuild = builds[index];
              return _CommunityBuildCard(savedBuild: savedBuild);
            },
          );
        },
      ),
    );
  }
}

class _CommunityBuildCard extends ConsumerWidget {
  final SavedBuild savedBuild;

  const _CommunityBuildCard({required this.savedBuild});

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(savedBuildsServiceProvider);
    final isLiked = service.hasUserLiked(savedBuild);
    final componentCount = savedBuild.components.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBuildDetails(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and author
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          savedBuild.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              savedBuild.authorName,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(savedBuild.createdAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\$${savedBuild.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Component chips
              Text(
                '$componentCount components',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: savedBuild.components.entries.map((entry) {
                  return _ComponentChip(
                    type: entry.key,
                    component: entry.value,
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              // Like and comment row
              Row(
                children: [
                  // Like button
                  InkWell(
                    onTap: () => _handleLike(ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${savedBuild.likesCount}',
                            style: TextStyle(
                              color: isLiked ? Colors.red : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comment indicator
                  Row(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Comments',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLike(WidgetRef ref) async {
    try {
      final service = ref.read(savedBuildsServiceProvider);
      await service.toggleLike(savedBuild.id);
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  void _showBuildDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuildDetailsSheet(savedBuild: savedBuild),
    );
  }
}

class _ComponentChip extends StatelessWidget {
  final ComponentType type;
  final Component component;

  const _ComponentChip({required this.type, required this.component});

  String get _typeLabel {
    switch (type) {
      case ComponentType.cpu:
        return 'CPU';
      case ComponentType.gpu:
        return 'GPU';
      case ComponentType.ram:
        return 'RAM';
      case ComponentType.motherboard:
        return 'MB';
      case ComponentType.storage:
        return 'SSD';
      case ComponentType.psu:
        return 'PSU';
      case ComponentType.pcCase:
        return 'Case';
      case ComponentType.cooling:
        return 'Cool';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _typeLabel,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            component.brand,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BuildDetailsSheet extends ConsumerStatefulWidget {
  final SavedBuild savedBuild;

  const _BuildDetailsSheet({required this.savedBuild});

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

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(
      buildCommentsProvider(widget.savedBuild.id),
    );
    final service = ref.watch(savedBuildsServiceProvider);
    final isLiked = service.hasUserLiked(widget.savedBuild);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title and price
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.savedBuild.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${widget.savedBuild.authorName}',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${widget.savedBuild.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Like button row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _handleLike,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? Colors.red.withAlpha(20)
                              : Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.savedBuild.likesCount} likes',
                              style: TextStyle(
                                color: isLiked ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Components section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.computer,
                      size: 18,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Components',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.savedBuild.components.length,
                  itemBuilder: (context, index) {
                    final entry = widget.savedBuild.components.entries
                        .elementAt(index);
                    return _HorizontalComponentCard(
                      type: entry.key,
                      component: entry.value,
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              // Comments section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment,
                      size: 18,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Comments list
              Expanded(
                child: commentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No comments yet',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentTile(
                          comment: comment,
                          buildId: widget.savedBuild.id,
                        );
                      },
                    );
                  },
                ),
              ),
              // Comment input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(top: BorderSide(color: Colors.grey[800]!)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSubmitting ? null : _submitComment,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLike() async {
    try {
      final service = ref.read(savedBuildsServiceProvider);
      await service.toggleLike(widget.savedBuild.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(savedBuildsServiceProvider);
      await service.addComment(widget.savedBuild.id, text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _HorizontalComponentCard extends StatelessWidget {
  final ComponentType type;
  final Component component;

  const _HorizontalComponentCard({required this.type, required this.component});

  String get _typeLabel {
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
        return 'PSU';
      case ComponentType.pcCase:
        return 'Case';
      case ComponentType.cooling:
        return 'Cooling';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _typeLabel,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              component.brand,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '\$${component.price.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.green, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final BuildComment comment;
  final String buildId;

  const _CommentTile({required this.comment, required this.buildId});

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(savedBuildsServiceProvider);
    final isOwner = comment.userId == service.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueAccent.withAlpha(50),
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.grey,
                  onPressed: () => _deleteComment(ref, context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.text),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
