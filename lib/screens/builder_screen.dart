import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../services/compatibility_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
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
          Space.screen,
          Space.sm,
          Space.screen,
          Space.xl,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(state: buildState),
                const SizedBox(height: Space.md),
                CompatibilityCard(report: compatibility),
                for (final type in _slots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm + 2),
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
    final c = context.rig;
    final count = state.selectedComponents.length;
    final total = BuilderScreen._slots.length;
    return RigCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        children: [
          RigGauge(
            progress: count / total,
            color: c.accent,
            size: 76,
            strokeWidth: 8,
            sweep: math.pi * 2,
            semanticLabel: '$count of $total parts selected',
            child: Text('$count/$total', style: context.metric(16)),
          ),
          const SizedBox(width: Space.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated total', style: context.text.bodySmall),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(state.totalPrice),
                    style: context.metric(28),
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  count == total
                      ? 'All parts selected'
                      : '${total - count} more to complete this build',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
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

    return Semantics(
      button: true,
      label: selected
          ? '${type.label}: ${part.name}. View details.'
          : 'Add ${type.label}',
      child: RigCard(
        tone: selected ? RigCardTone.selected : RigCardTone.normal,
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.md,
          Space.xs,
          Space.md,
        ),
        onTap: selected ? () => onView(part) : onSelect,
        child: Row(
          children: [
            RigIconBox(
              icon: type.icon,
              color: selected ? c.accent : c.textSecondary,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: context.text.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    selected ? part.name : 'Not selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: selected
                        ? context.text.titleSmall
                        : context.text.bodyMedium!.copyWith(
                            color: c.textSecondary,
                          ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatPrice(part.price),
                      style: context.metric(13, color: c.accent),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(selected ? Icons.swap_horiz : Icons.add_circle),
              color: selected ? c.textSecondary : c.accent,
              tooltip: selected ? 'Change ${type.label}' : 'Add ${type.label}',
              onPressed: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}
