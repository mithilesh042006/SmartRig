import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../services/compatibility_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/compatibility_card.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_performance.dart';
import '../widgets/rig_surfaces.dart';
import 'build_3d_viewer_screen.dart';
import 'component_selection_screen.dart';
import 'product_detail_screen.dart';
import 'review_build_screen.dart';

class BuilderScreen extends ConsumerWidget {
  const BuilderScreen({super.key});

  static const _slots = [
    ComponentType.cpu,
    ComponentType.motherboard,
    ComponentType.gpu,
    ComponentType.ram,
    ComponentType.storage,
    ComponentType.psu,
    ComponentType.pcCase,
    ComponentType.cooling,
  ];

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _clearBuild(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Clear this build?',
      message:
          'All selected parts will be removed. Saved builds are not affected.',
      confirmLabel: 'Clear',
    );
    if (confirmed) ref.read(buildProvider.notifier).clearBuild();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState = ref.watch(buildProvider);
    final compatibility = ref.watch(compatibilityProvider);
    final hasParts = buildState.selectedComponents.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Build'),
        actions: [
          if (hasParts)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _clearBuild(context, ref),
              tooltip: 'Clear build',
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.lg,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(state: buildState),
                const SizedBox(height: Space.md),
                CompatibilityCard(report: compatibility),
                // Two columns of part blocks, which fill with colour as you pick.
                for (var i = 0; i < _slots.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm + 2),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final type in [_slots[i], _slots[i + 1]]) ...[
                            if (type != _slots[i])
                              const SizedBox(width: Space.sm + 2),
                            Expanded(
                              child: _SlotCard(
                                type: type,
                                component: buildState.selectedComponents[type],
                                onSelect: () => _push(
                                  context,
                                  ComponentSelectionScreen(componentType: type),
                                ),
                                onView: (component) => _push(
                                  context,
                                  ProductDetailScreen(component: component),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RigActionBar(
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: hasParts
                    ? () => _push(context, const ReviewBuildScreen())
                    : null,
                child: const Text('Review Build', maxLines: 1),
              ),
            ),
            const SizedBox(width: Space.md),
            OutlinedButton.icon(
              onPressed: () => _push(context, const Build3DViewerScreen()),
              icon: const Icon(Icons.view_in_ar),
              label: const Text('View 3D', maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BuildState state;

  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final count = state.selectedComponents.length;
    final total = BuilderScreen._slots.length;
    return RigInkCard(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.xl,
        Space.xl,
        Space.lg,
      ),
      child: Builder(
        builder: (context) {
          final c = context.rig;
          return Column(
            children: [
              RigGauge(
                progress: count / total,
                color: c.volt,
                segments: total,
                semanticLabel: '$count of $total parts selected',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count/$total', style: context.metric(20)),
                    const SizedBox(height: Space.xs),
                    Text(
                      formatMoney(state.totalPrice),
                      style: context.metric(34, color: c.volt),
                    ),
                    Text('Estimated total', style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                count == total
                    ? 'All parts selected'
                    : '${total - count} more to complete this build',
                textAlign: TextAlign.center,
                style: context.text.titleSmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final ComponentType type;
  final Component? component;
  final VoidCallback onSelect;
  final ValueChanged<Component> onView;

  const _SlotCard({
    required this.type,
    required this.component,
    required this.onSelect,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final part = component;
    final selected = part != null;
    final foreground = selected ? RigPalette.ink : c.textPrimary;

    return Semantics(
      button: true,
      label: selected
          ? '${type.label}: ${part.name}. View details.'
          : 'Add ${type.label}',
      child: RigCard(
        color: selected ? type.tint : null,
        padding: const EdgeInsets.fromLTRB(
          Space.md + 2,
          Space.sm + 2,
          Space.xs,
          Space.md + 2,
        ),
        onTap: selected ? () => onView(part) : onSelect,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected)
                  PartThumbnail(component: part, size: 44)
                else
                  PartTile(type: type, size: 44),
                const Spacer(),
                IconButton(
                  icon: Icon(selected ? Icons.swap_horiz : Icons.add),
                  color: foreground,
                  tooltip: selected
                      ? 'Change ${type.label}'
                      : 'Add ${type.label}',
                  onPressed: onSelect,
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              type.label,
              style: context.text.labelMedium!.copyWith(
                color: selected ? RigPalette.ink : c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text(
                selected ? part.name : 'Not selected',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall!.copyWith(color: foreground),
              ),
            ),
            if (selected) ...[
              const Spacer(),
              const SizedBox(height: Space.sm),
              Text(
                formatPrice(part.price),
                style: context.metric(16, color: RigPalette.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
