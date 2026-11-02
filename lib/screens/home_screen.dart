import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/build_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/auth_service.dart';
import '../services/saved_builds_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_performance.dart';
import '../widgets/rig_surfaces.dart';
import 'community_screen.dart';
import 'compare_builds_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _recentLimit = 3;

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
            Space.screen,
            Space.lg,
            Space.screen,
            Space.xxl,
          ),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onProfile: () => _openTab(ref, AppTab.profile)),
                const SizedBox(height: Space.xl),
                _HeroCard(
                  selectedCount: selectedCount,
                  onStart: () => _openTab(ref, AppTab.build),
                ),
                const SizedBox(height: Space.lg),
                buildsAsync.when(
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
                const SizedBox(height: Space.section),
                const SectionHeader(title: 'Quick actions'),
                _QuickActions(onBuild: () => _openTab(ref, AppTab.build)),
                const SizedBox(height: Space.section),
                SectionHeader(
                  title: 'Recent builds',
                  actionLabel: (buildsAsync.value?.length ?? 0) > _recentLimit
                      ? 'See all'
                      : null,
                  onAction: () => _openTab(ref, AppTab.saved),
                ),
                buildsAsync.when(
                  loading: () => const Column(
                    children: [
                      Skeleton(height: 96, radius: Radii.lg),
                      SizedBox(height: Space.md),
                      Skeleton(height: 96, radius: Radii.lg),
                    ],
                  ),
                  error: (error, _) => ErrorState(
                    error: error,
                    title: 'Could not load your builds',
                    onRetry: () => ref.invalidate(savedBuildsStreamProvider),
                  ),
                  data: (builds) => builds.isEmpty
                      ? const _NoBuildsYet()
                      : Column(
                          children: [
                            for (final build in builds.take(_recentLimit))
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.md,
                                ),
                                child: _RecentBuildCard(savedBuild: build),
                              ),
                          ],
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
        const RigMark(),
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
    final c = context.rig;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CircuitPattern(color: c.onHero.withValues(alpha: 0.16)),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build Your\nDream PC',
                  style: context.text.displaySmall!.copyWith(color: c.onHero),
                ),
                const SizedBox(height: Space.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    'Pick real parts, check compatibility, and estimate '
                    'performance before you buy.',
                    style: context.text.bodyMedium!.copyWith(
                      color: c.onHeroMuted,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.onHero,
                    foregroundColor: c.heroStart,
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
    final c = context.rig;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: 'Saved',
              value: total,
              icon: Icons.bookmark,
              color: c.accent,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: _Stat(
              label: 'Public',
              value: public,
              icon: Icons.public,
              color: c.success,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: _Stat(
              label: 'Private',
              value: private,
              icon: Icons.lock,
              color: c.accentAlt,
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
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == null ? '$label builds loading' : '$value $label builds',
      excludeSemantics: true,
      child: RigCard(
        padding: const EdgeInsets.all(Space.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: Space.sm),
            value == null
                ? const Skeleton(width: 28, height: 24)
                : Text('$value', style: context.metric(24)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onBuild;

  const _QuickActions({required this.onBuild});

  @override
  Widget build(BuildContext context) {
    final c = context.rig;
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Column(
      children: [
        _QuickAction(
          icon: Icons.handyman,
          color: c.accent,
          title: 'Builder',
          subtitle: 'Choose parts for your build',
          onTap: onBuild,
        ),
        const SizedBox(height: Space.md),
        _QuickAction(
          icon: Icons.compare_arrows,
          color: c.accentAlt,
          title: 'Compare builds',
          subtitle: 'Put up to three saved builds side by side',
          onTap: () => push(const CompareBuildsScreen()),
        ),
        const SizedBox(height: Space.md),
        _QuickAction(
          icon: Icons.groups,
          color: c.success,
          title: 'Community builds',
          subtitle: 'See what other builders shared',
          onTap: () => push(const CommunityScreen()),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: RigCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Space.md + 2),
        child: Row(
          children: [
            RigIconBox(icon: icon, color: color),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.rig.textSecondary),
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
      child: RigCard(
        onTap: () => openSavedBuild(context, ref, savedBuild),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    savedBuild.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  formatMoney(savedBuild.totalPrice, decimals: 0),
                  style: context.metric(16, color: context.rig.accent),
                ),
              ],
            ),
            BuildHighlights(components: savedBuild.components),
            if (result != null) ...[
              const SizedBox(height: Space.sm),
              RigPill(
                label: 'Est. score ${result.systemScore.toStringAsFixed(0)}',
                icon: Icons.speed,
                color: scoreColor(context, result.systemScore),
              ),
            ],
          ],
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
                Text('No saved builds yet', style: context.text.titleSmall),
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
