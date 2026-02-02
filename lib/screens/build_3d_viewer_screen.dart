import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/component.dart';
import '../providers/build_provider.dart';

class Build3DViewerScreen extends ConsumerWidget {
  const Build3DViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState = ref.watch(buildProvider);
    final modelPath = _getModelPath(buildState);

    if (modelPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D Build Viewer'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, size: 80, color: Colors.grey[600]),
                const SizedBox(height: 24),
                const Text(
                  'Select a Case First',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'To view your build in 3D, please select a PC case first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Build Viewer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context, buildState),
            tooltip: 'Build Info',
          ),
        ],
      ),
      body: Column(
        children: [
          // Component indicator chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildComponentChips(buildState)),
            ),
          ),
          // 3D Model Viewer
          Expanded(
            child: ModelViewer(
              src: modelPath,
              alt: 'PC Build 3D Model',
              ar: false,
              autoRotate: true,
              autoRotateDelay: 2000,
              rotationPerSecond: '30deg',
              cameraControls: true,
              disableZoom: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              loading: Loading.eager,
            ),
          ),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'Drag to rotate • Pinch to zoom',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
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
    if (hasCpu) {
      return 'assets/case_motherboard_cpu.glb';
    }
    if (hasMotherboard) {
      return 'assets/case_motherboard.glb';
    }
    if (hasPowerSupply) {
      return 'assets/case_powersource.glb';
    }
    // Default: just the case
    return 'assets/case.glb';
  }

  List<Widget> _buildComponentChips(BuildState state) {
    final components = [
      (ComponentType.pcCase, 'Case', Icons.computer),
      (ComponentType.cpu, 'CPU', Icons.memory),
      (ComponentType.gpu, 'GPU', Icons.tv),
      (ComponentType.ram, 'RAM', Icons.storage),
      (ComponentType.cooling, 'Cooling', Icons.ac_unit),
    ];

    return components.map((item) {
      final isSelected = state.selectedComponents[item.$1] != null;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          avatar: Icon(
            item.$3,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey,
          ),
          label: Text(item.$2),
          backgroundColor: isSelected ? Colors.green : Colors.grey[800],
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }

  void _showInfoDialog(BuildContext context, BuildState state) {
    final components = state.selectedComponents.entries
        .where((e) => e.value != null)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current Build'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${components.length} components selected',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            ...components.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
