import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'rig_surfaces.dart';

/// Centered message for empty lists and screens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.section),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RigIconBox(icon: icon, size: 72),
              const SizedBox(height: Space.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleLarge,
              ),
              const SizedBox(height: Space.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium!.copyWith(
                  color: context.rig.textSecondary,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: Space.xxl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed load, with a way to try again.
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String title;

  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.section),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RigIconBox(icon: Icons.error_outline, color: c.error, size: 64),
              const SizedBox(height: Space.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Space.sm),
              Text(
                friendlyError(error),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium!.copyWith(
                  color: c.textSecondary,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: Space.xl),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A pulsing placeholder block. Static when reduced motion is on.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.sm,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.rig.surfaceRaised,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like the list that is loading.
class SkeletonList extends StatelessWidget {
  final int count;
  final double imageSize;
  final String semanticLabel;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.imageSize = 88,
    this.semanticLabel = 'Loading',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(Space.screen),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: Space.md),
        itemBuilder: (_, _) => RigCard(
          child: Row(
            children: [
              Skeleton(width: imageSize, height: imageSize, radius: Radii.md),
              const SizedBox(width: Space.lg),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(),
                    SizedBox(height: Space.sm),
                    Skeleton(width: 140),
                    SizedBox(height: Space.lg),
                    Skeleton(width: 80, height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button label that swaps to a spinner while work is running.
class LoadingLabel extends StatelessWidget {
  final bool loading;
  final String label;
  final Color? spinnerColor;

  const LoadingLabel({
    super.key,
    required this.loading,
    required this.label,
    this.spinnerColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) return Text(label);
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: spinnerColor ?? context.rig.textSecondary,
        semanticsLabel: '$label in progress',
      ),
    );
  }
}

/// Inline banner for form-level errors.
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: c.soft(c.error),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: c.error, size: 20),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium!.copyWith(color: c.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRigSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirmation for sign-out and deletes. Resolves to true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = context.rig;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: c.error),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
