import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/component.dart';
import '../models/component_type_ui.dart';
import '../providers/build_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/rig_art.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';

class Build3DViewerScreen extends ConsumerWidget {
  const Build3DViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState = ref.watch(buildProvider);
    final modelPath = _getModelPath(buildState);

    if (modelPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D View')),
        body: EmptyState(
          icon: Icons.view_in_ar,
          title: 'Select a case first',
          message: 'To view your build in 3D, please select a PC case first.',
          actionLabel: 'Back to build',
          onAction: () => Navigator.maybePop(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('3D View')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  child: BlueprintGrid(
                    child: ModelViewer(
                      src: modelPath,
                      alt: 'Simplified 3D preview of your PC build',
                      ar: false,
                      autoRotate: true,
                      autoRotateDelay: 2000,
                      rotationPerSecond: '30deg',
                      cameraControls: true,
                      disableZoom: false,
                      backgroundColor: Colors.transparent,
                      loading: Loading.eager,
                    ),
                  ),
                ),
              ),
            ),
            _InfoPanel(state: buildState),
          ],
        ),
      ),
    );
  }

  String? _getModelPath(BuildState state) {
    // Case is required to show any 3D model
    if (state.selectedComponents[ComponentType.pcCase] == null) {
      return null;
    }

    final bool hasGpu = state.selectedComponents[ComponentType.gpu] != null;
    final bool hasMotherboard =
        state.selectedComponents[ComponentType.motherboard] != null;
    final bool hasRam = state.selectedComponents[ComponentType.ram] != null;
    final bool hasCpu = state.selectedComponents[ComponentType.cpu] != null;
    final bool hasCooling =
        state.selectedComponents[ComponentType.cooling] != null;
    final bool hasPowerSupply =
        state.selectedComponents[ComponentType.psu] != null;

    // Priority-based model selection
    if (hasCooling) {
      return 'assets/case_cooling.glb';
    }
    if (hasGpu && hasRam) {
      return 'assets/case_motherboard_gpu_ram.glb';
    }
    if (hasGpu) {
      return 'assets/case_motherboard_gpu.glb';
    }
    if (hasRam) {
      return 'assets/case_motherboard_ram.glb';
    }
    // No dedicated CPU or PSU models yet; these stages reuse the closest model.
    if (hasCpu || hasMotherboard) {
      return 'assets/case_motherboard.glb';
    }
    if (hasPowerSupply) {
      return 'assets/case_cooling.glb';
    }
    // Default: just the case
    return 'assets/case.glb';
  }
}

class _InfoPanel extends StatelessWidget {
  final BuildState state;

  const _InfoPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.lg,
        ),
        child: RigInkCard(
          padding: const EdgeInsets.all(Space.lg + 2),
          child: Builder(
            builder: (context) {
              final c = context.rig;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.selectedComponents.length} of '
                          '${ComponentType.values.length} parts',
                          style: context.text.titleMedium,
                        ),
                      ),
                      Text(
                        formatMoney(state.totalPrice),
                        style: context.metric(24, color: c.volt),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.xs + 2,
                    runSpacing: Space.xs + 2,
                    children: [
                      for (final type in const [
                        ComponentType.pcCase,
                        ComponentType.motherboard,
                        ComponentType.cpu,
                        ComponentType.gpu,
                        ComponentType.ram,
                        ComponentType.psu,
                        ComponentType.cooling,
                      ])
                        Semantics(
                          label:
                              '${type.label} ${state.selectedComponents[type] != null ? 'selected' : 'not selected'}',
                          excludeSemantics: true,
                          child: RigPill(
                            label: type.shortLabel,
                            icon: state.selectedComponents[type] != null
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: state.selectedComponents[type] != null
                                ? type.tint
                                : c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    'Drag to rotate, pinch to zoom. This is a simplified preview of '
                    'your build stage, not your exact parts.',
                    style: context.text.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
