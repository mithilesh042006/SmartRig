import 'package:flutter/material.dart';
import '../services/compatibility_service.dart';

/// Summary of a build's compatibility checks; expands to show each one.
class CompatibilityCard extends StatelessWidget {
  final CompatibilityReport report;

  const CompatibilityCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final overall = report.overall;
    if (overall == null) return const SizedBox.shrink();

    final (icon, color) = _style(overall);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        // Rebuilds expanded if a later part change introduces a problem.
        key: ValueKey(overall),
        initiallyExpanded:
            overall == CompatibilityStatus.incompatible ||
            overall == CompatibilityStatus.warning,
        leading: Icon(icon, color: color),
        title: const Text(
          'Compatibility',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_summary(), style: TextStyle(color: color)),
        children: [
          for (final check in report.checks)
            ListTile(
              dense: true,
              leading: Icon(
                _style(check.status).$1,
                color: _style(check.status).$2,
                size: 20,
              ),
              title: Text(check.title),
              subtitle: Text(check.message),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Based on product titles and our parts catalogue. Confirm critical details on the manufacturer page before buying.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  String _summary() {
    final parts = [
      _part(CompatibilityStatus.incompatible, 'problem', 'problems'),
      _part(CompatibilityStatus.warning, 'warning', 'warnings'),
      _part(CompatibilityStatus.unknown, 'not verified', 'not verified'),
    ].whereType<String>();
    return parts.isEmpty ? 'All checks passed' : parts.join(' · ');
  }

  String? _part(CompatibilityStatus status, String one, String many) {
    final count = report.count(status);
    if (count == 0) return null;
    return '$count ${count == 1 ? one : many}';
  }

  static (IconData, Color) _style(CompatibilityStatus status) =>
      switch (status) {
        CompatibilityStatus.compatible => (Icons.check_circle, Colors.green),
        CompatibilityStatus.unknown => (Icons.help_outline, Colors.grey),
        CompatibilityStatus.warning => (Icons.warning_amber, Colors.orange),
        CompatibilityStatus.incompatible => (Icons.error, Colors.red),
      };
}
