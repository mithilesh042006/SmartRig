import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_tokens.dart';
import 'builder_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_builds_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static const _screens = [
    HomeScreen(),
    BuilderScreen(),
    SavedBuildsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(index: selected.index, children: _screens),
      bottomNavigationBar: _RigNavigationBar(
        selected: selected,
        onSelect: ref.read(selectedTabProvider.notifier).select,
      ),
    );
  }
}

class _RigNavigationBar extends StatelessWidget {
  final AppTab selected;
  final ValueChanged<AppTab> onSelect;

  const _RigNavigationBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.lg,
                Space.md,
              ),
              padding: const EdgeInsets.all(Space.xs + 2),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  for (final (tab, icon, activeIcon, label) in const [
                    (AppTab.home, Icons.home_outlined, Icons.home, 'Home'),
                    (
                      AppTab.build,
                      Icons.handyman_outlined,
                      Icons.handyman,
                      'Build',
                    ),
                    (
                      AppTab.saved,
                      Icons.bookmark_outline,
                      Icons.bookmark,
                      'Saved',
                    ),
                    (
                      AppTab.profile,
                      Icons.person_outline,
                      Icons.person,
                      'Profile',
                    ),
                  ])
                    Expanded(
                      child: _NavItem(
                        icon: tab == selected ? activeIcon : icon,
                        label: label,
                        selected: tab == selected,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final color = selected ? c.onAccent : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.normal),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
          decoration: BoxDecoration(
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
