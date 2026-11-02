import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'component.dart';

/// Display helpers shared by every screen that shows a component type.
extension ComponentTypeUi on ComponentType {
  IconData get icon => switch (this) {
    ComponentType.cpu => Icons.memory,
    ComponentType.gpu => Icons.videogame_asset,
    ComponentType.ram => Icons.view_week,
    ComponentType.motherboard => Icons.developer_board,
    ComponentType.storage => Icons.sd_storage,
    ComponentType.psu => Icons.bolt,
    ComponentType.pcCase => Icons.dns,
    ComponentType.cooling => Icons.ac_unit,
  };

  /// Each part keeps its own colour wherever it appears.
  Color get tint => switch (this) {
    ComponentType.cpu => RigPalette.volt,
    ComponentType.gpu => RigPalette.tangerine,
    ComponentType.ram => RigPalette.lilac,
    ComponentType.motherboard => RigPalette.sky,
    ComponentType.storage => RigPalette.sun,
    ComponentType.psu => RigPalette.blush,
    ComponentType.pcCase => RigPalette.mint,
    ComponentType.cooling => RigPalette.ice,
  };

  String get label => switch (this) {
    ComponentType.cpu => 'CPU',
    ComponentType.gpu => 'GPU',
    ComponentType.ram => 'RAM',
    ComponentType.motherboard => 'Motherboard',
    ComponentType.storage => 'Storage',
    ComponentType.psu => 'Power Supply',
    ComponentType.pcCase => 'Case',
    ComponentType.cooling => 'Cooling',
  };

  /// Compact label for chips.
  String get shortLabel => switch (this) {
    ComponentType.cpu => 'CPU',
    ComponentType.gpu => 'GPU',
    ComponentType.ram => 'RAM',
    ComponentType.motherboard => 'MB',
    ComponentType.storage => 'SSD',
    ComponentType.psu => 'PSU',
    ComponentType.pcCase => 'Case',
    ComponentType.cooling => 'Cool',
  };
}
