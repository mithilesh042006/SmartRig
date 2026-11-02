import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/build_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/auth_service.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_art.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';
import 'community_screen.dart';
import 'compare_builds_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _recentLimit = 4;

  void _openTab(WidgetRef ref, AppTab tab) =>
      ref.read(selectedTabProvider.notifier).select(tab);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildsAsync = ref.watch(savedBuildsStreamProvider);
    final selectedCount = ref.watch(
      buildProvider.select((b) => b.selectedComponents.length),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.xl,
          ),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onProfile: () => _openTab(ref, AppTab.profile)),
                const SizedBox(height: Space.lg),
                RigReveal(
                  child: _HeroCard(
                    selectedCount: selectedCount,
                    onStart: () => _openTab(ref, AppTab.build),
                  ),
                ),
                const SizedBox(height: Space.md),
                RigReveal(
                  order: 1,
                  child: buildsAsync.when(
                    loading: () => const _StatsRow(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (builds) {
                      final public = builds.where((b) => b.isPublic).length;
                      return _StatsRow(
                        total: builds.length,
                        public: public,
                        private: builds.length - public,
                      );
                    },
                  ),
                ),
                const SizedBox(height: Space.md),
                const RigReveal(order: 2, child: _QuickActions()),
                const SizedBox(height: Space.section),
                SectionHeader(
                  title: 'My last builds',
                  actionLabel: (buildsAsync.value?.length ?? 0) > _recentLimit
                      ? 'See all'
                      : null,
                  onAction: () => _openTab(ref, AppTab.saved),
                ),
                buildsAsync.when(
                  loading: () => const Skeleton(height: 190, radius: Radii.lg),
                  error: (error, _) => ErrorState(
                    error: error,
                    title: 'Could not load your builds',
                    onRetry: () => ref.invalidate(savedBuildsStreamProvider),
                  ),
                  data: (builds) => builds.isEmpty
                      ? const _NoBuildsYet()
                      : _RecentBuilds(
                          builds: builds.take(_recentLimit).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final VoidCallback onProfile;

  const _Header({required this.onProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.displayName?.trim() ?? '';
    final firstName = name.isEmpty ? null : name.split(RegExp(r'\s+')).first;

    return Row(
      children: [
        const RigMark(size: 44),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName == null ? 'Welcome back' : 'Welcome back, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
              Text('SmartRig', style: context.text.titleLarge),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Open profile',
          excludeSemantics: true,
          child: InkResponse(
            onTap: onProfile,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: InitialsAvatar(
                initials: initialsOf(
                  name.isEmpty ? (user?.email ?? '?') : name,
                ),
                imageUrl: user?.photoURL,
                size: 44,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onStart;

  const _HeroCard({required this.selectedCount, required this.onStart});

  @override
  Widget build(BuildContext context) {
    // The tower sits beside the copy, and steps aside when text is enlarged.
    final showArt =
        MediaQuery.textScalerOf(context).scale(10) <= 12 &&
        MediaQuery.sizeOf(context).width >= 360;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: RigPalette.volt,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -50,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                color: RigPalette.sun.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (showArt)
            const Positioned(
              right: Space.md,
              top: Space.lg,
              bottom: 92,
              child: RigTowerArt(),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Build Your\nDream PC',
                  style: context.text.displayMedium!.copyWith(
                    color: RigPalette.ink,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: Space.md),
                Padding(
                  padding: EdgeInsets.only(right: showArt ? 150 : 0),
                  child: Text(
                    'Pick real parts, check compatibility, and estimate '
                    'performance before you buy.',
                    style: context.text.bodyMedium!.copyWith(
                      color: RigPalette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: RigPalette.ink,
                    foregroundColor: RigPalette.volt,
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    selectedCount > 0
                        ? 'Continue Building ($selectedCount/8)'
                        : 'Start Building',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int? total;
  final int? public;
  final int? private;

  const _StatsRow({this.total, this.public, this.private});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: 'Saved',
              value: total,
              color: RigPalette.tangerine,
            ),
          ),
          const SizedBox(width: Space.sm + 2),
          Expanded(
            child: _Stat(
              label: 'Public',
              value: public,
              color: RigPalette.mint,
            ),
          ),
          const SizedBox(width: Space.sm + 2),
          Expanded(
            child: _Stat(
              label: 'Private',
              value: private,
              color: RigPalette.lilac,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == null ? '$label builds loading' : '$value $label builds',
      excludeSemantics: true,
      child: RigCard(
        color: color,
        padding: const EdgeInsets.all(Space.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            value == null
                ? const Skeleton(width: 32, height: 36)
                : Text(
                    '$value',
                    style: context.metric(36, color: RigPalette.ink),
                  ),
            const SizedBox(height: Space.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(color: RigPalette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.compare_arrows,
              title: 'Compare builds',
              subtitle: 'Up to three, side by side',
              onTap: () => push(const CompareBuildsScreen()),
            ),
          ),
          const SizedBox(width: Space.sm + 2),
          Expanded(
            child: _QuickAction(
              icon: Icons.groups,
              title: 'Community builds',
              subtitle: 'See what others shared',
              dark: true,
              onTap: () => push(const CommunityScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool dark;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RigIconBox(icon: icon, size: 44),
              Icon(Icons.north_east, color: context.rig.textPrimary, size: 22),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(subtitle, style: context.text.bodySmall),
        ],
      ),
    );

    return Semantics(
      button: true,
      child: dark
          ? RigInkCard(
              padding: const EdgeInsets.all(Space.lg),
              onTap: onTap,
              child: content,
            )
          : RigCard(onTap: onTap, child: content),
    );
  }
}

class _RecentBuilds extends StatelessWidget {
  final List<SavedBuild> builds;

  const _RecentBuilds({required this.builds});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final build in builds)
              Padding(
                padding: const EdgeInsets.only(right: Space.md),
                child: SizedBox(
                  width: 236,
                  child: _RecentBuildCard(savedBuild: build),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentBuildCard extends ConsumerWidget {
  final SavedBuild savedBuild;

  const _RecentBuildCard({required this.savedBuild});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = performanceOf(savedBuild);
    return Semantics(
      button: true,
      child: RigInkCard(
        padding: const EdgeInsets.all(Space.lg + 2),
        onTap: () => openSavedBuild(context, ref, savedBuild),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(savedBuild.createdAt),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Space.xs),
              Text(
                savedBuild.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
              BuildHighlights(components: savedBuild.components),
              const SizedBox(height: Space.lg),
              const Spacer(),
              PartStrip(components: savedBuild.components),
              const SizedBox(height: Space.md),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  Text(
                    formatMoney(savedBuild.totalPrice, decimals: 0),
                    style: context.metric(24, color: context.rig.volt),
                  ),
                  if (result != null)
                    RigPill(
                      label:
                          'Est. score ${result.systemScore.toStringAsFixed(0)}',
                      color: context.rig.textPrimary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoBuildsYet extends StatelessWidget {
  const _NoBuildsYet();

  @override
  Widget build(BuildContext context) {
    return RigCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        children: [
          const RigIconBox(icon: Icons.bookmark_add_outlined),
          const SizedBox(width: Space.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No saved builds yet', style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Builds you save will show up here.',
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
