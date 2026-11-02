import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/performance_service.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import 'rig_feedback.dart';

/// The estimate for a saved build, or null without both a CPU and GPU.
PerformanceResult? performanceOf(SavedBuild build) =>
    const PerformanceService().calculatePerformance(
      BuildState(
        selectedComponents: Map<ComponentType, Component?>.from(
          build.components,
        ),
      ),
    );

/// Puts a saved build in the builder and opens the Build tab.
void openSavedBuild(BuildContext context, WidgetRef ref, SavedBuild build) {
  final notifier = ref.read(buildProvider.notifier);
  notifier.clearBuild();
  for (final component in build.components.values) {
    notifier.selectComponent(component);
  }
  ref.read(selectedTabProvider.notifier).select(AppTab.build);
  showRigSnack(context, 'Loaded "${build.name}"');
}

/// The CPU and GPU of a build, one line each, when they were selected.
class BuildHighlights extends StatelessWidget {
  final Map<ComponentType, Component> components;

  const BuildHighlights({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    final highlights = [
      ComponentType.cpu,
      ComponentType.gpu,
    ].where(components.containsKey).toList();
    if (highlights.isEmpty) {
      return Text(
        '${components.length} ${components.length == 1 ? 'part' : 'parts'} selected',
        style: context.text.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in highlights)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Row(
              children: [
                Icon(type.icon, size: 15, color: context.rig.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    components[type]!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Round avatar with a person's initials.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final String? imageUrl;

  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: c.accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.soft(c.accent),
        shape: BoxShape.circle,
      ),
      child: imageUrl == null
          ? fallback
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Small rounded photo of a selected part.
class PartThumbnail extends StatelessWidget {
  final Component component;
  final double size;

  const PartThumbnail({super.key, required this.component, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: ProductImage(
        url: component.imageUrl,
        fallbackIcon: component.type.icon,
        size: size,
      ),
    );
  }
}

/// A product photo on a white backdrop, since listing photos assume white.
class ProductImage extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  final double? size;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.url,
    this.fallbackIcon = Icons.memory,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final placeholder = Container(
      width: size,
      height: size,
      color: c.surfaceRaised,
      child: Icon(fallbackIcon, color: c.textSecondary),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Image.network(
        url!,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : ColoredBox(color: c.surfaceRaised),
      ),
    );
  }
}
