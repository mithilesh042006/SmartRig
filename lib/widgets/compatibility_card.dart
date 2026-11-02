import 'package:flutter/material.dart';
import '../services/compatibility_service.dart';
import '../theme/app_tokens.dart';
import 'rig_surfaces.dart';

/// Summary of a build's compatibility checks; expands to show each one.
class CompatibilityCard extends StatelessWidget {
  final CompatibilityReport report;

  const CompatibilityCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final overall = report.overall;
    if (overall == null) return const SizedBox.shrink();

    final (icon, color) = _style(context, overall);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: RigCard(
        padding: EdgeInsets.zero,
        tone: switch (overall) {
          CompatibilityStatus.incompatible => RigCardTone.error,
          CompatibilityStatus.warning => RigCardTone.warning,
          _ => RigCardTone.normal,
        },
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // Rebuilds expanded if a later part change introduces a problem.
            key: ValueKey(overall),
            initiallyExpanded:
                overall == CompatibilityStatus.incompatible ||
                overall == CompatibilityStatus.warning,
            leading: RigIconBox(icon: icon, color: color, size: 40),
            title: Text('Compatibility', style: context.text.titleSmall),
            subtitle: Text(
              _summary(),
              style: context.text.bodySmall!.copyWith(color: color),
            ),
            children: [
              for (final check in report.checks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    _style(context, check.status).$1,
                    color: _style(context, check.status).$2,
                    size: 20,
                  ),
                  title: Text(check.title, style: context.text.labelLarge),
                  subtitle: Text(check.message, style: context.text.bodySmall),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.xs,
                  Space.lg,
                  Space.md,
                ),
                child: Text(
                  'Based on product titles and our parts catalogue. Confirm critical details on the manufacturer page before buying.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
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

  static (IconData, Color) _style(
    BuildContext context,
    CompatibilityStatus status,
  ) {
    final c = context.rig;
    return switch (status) {
      CompatibilityStatus.compatible => (Icons.check_circle, c.success),
      CompatibilityStatus.unknown => (Icons.help_outline, c.textSecondary),
      CompatibilityStatus.warning => (Icons.warning_amber, c.warning),
      CompatibilityStatus.incompatible => (Icons.error, c.error),
    };
  }
}
