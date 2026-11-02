import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/build_widgets.dart';
import '../widgets/rig_feedback.dart';
import '../widgets/rig_surfaces.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final c = context.rig;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const EmptyState(
          icon: Icons.person_outline,
          title: 'Not logged in',
          message: 'Sign in to see your account.',
        ),
      );
    }

    final name = user.displayName?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.lg,
        ),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RigCard(
                color: RigPalette.volt,
                padding: const EdgeInsets.all(Space.xl),
                child: Row(
                  children: [
                    InitialsAvatar(
                      initials: initialsOf(
                        name.isEmpty ? (user.email ?? '?') : name,
                      ),
                      imageUrl: user.photoURL,
                      size: 76,
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'No name set' : name,
                            style: context.text.headlineMedium!.copyWith(
                              color: RigPalette.ink,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            user.email ?? 'No email',
                            style: context.text.bodySmall!.copyWith(
                              color: RigPalette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Appearance'),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_outlined),
                    label: Text('System'),
                  ),
                ],
                selected: {ref.watch(themeProvider)},
                onSelectionChanged: (selection) =>
                    ref.read(themeProvider.notifier).setTheme(selection.first),
              ),
              const SizedBox(height: Space.section),
              const SectionHeader(title: 'Account'),
              RigCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Account created',
                      value: formatDate(user.metadata.creationTime),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Last sign in',
                      value: formatDate(user.metadata.lastSignInTime),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.error,
                  side: BorderSide(color: c.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
    );

    if (confirmed) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        // AuthWrapper in main.dart will automatically redirect to LoginScreen
      } catch (e) {
        if (context.mounted) {
          showRigSnack(context, 'Sign out failed: ${friendlyError(e)}');
        }
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
      child: Row(
        children: [
          Icon(icon, color: context.rig.textSecondary, size: 20),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          const SizedBox(width: Space.sm),
          Text(value, style: context.text.labelLarge),
        ],
      ),
    );
  }
}
