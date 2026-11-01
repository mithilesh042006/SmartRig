import 'package:flutter/material.dart';
import 'component.dart';

/// Display helpers shared by every screen that shows a component type.
extension ComponentTypeUi on ComponentType {
  IconData get icon => switch (this) {
    ComponentType.cpu => Icons.memory,
    ComponentType.gpu => Icons.tv,
    ComponentType.ram => Icons.storage,
    ComponentType.motherboard => Icons.developer_board,
    ComponentType.storage => Icons.sd_storage,
    ComponentType.psu => Icons.power,
    ComponentType.pcCase => Icons.computer,
    ComponentType.cooling => Icons.ac_unit,
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
