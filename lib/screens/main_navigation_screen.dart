import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/rig_surfaces.dart';
import 'builder_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_builds_screen.dart';

/// Main navigation screen with a floating dock
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
      bottomNavigationBar: _RigDock(
        selected: selected,
        onSelect: ref.read(selectedTabProvider.notifier).select,
      ),
    );
  }
}

class _RigDock extends StatelessWidget {
  final AppTab selected;
  final ValueChanged<AppTab> onSelect;

  const _RigDock({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.rig.background,
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
                Space.xs,
                Space.lg,
                Space.md,
              ),
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: RigPalette.ink,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: RigInk(
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
                        // The active tab takes more room for its label.
                        flex: tab == selected ? 5 : 3,
                        child: _DockItem(
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
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    final color = selected ? c.onVolt : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.normal),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? c.volt : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              if (selected) ...[
                const SizedBox(width: Space.xs + 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: context.text.labelLarge!.copyWith(color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
