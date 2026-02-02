import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent.withAlpha(30),
              child: Text(
                _getInitials(user.displayName ?? user.email ?? '?'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Display Name
            Text(
              user.displayName ?? 'No Name Set',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              user.email ?? 'No Email',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Account Info Section
            _buildSectionTitle('Account Information'),
            const SizedBox(height: 12),
            _buildInfoTile(
              icon: Icons.email_outlined,
              title: 'Email',
              value: user.email ?? 'Not set',
            ),
            _buildInfoTile(
              icon: Icons.person_outline,
              title: 'Display Name',
              value: user.displayName ?? 'Not set',
            ),
            _buildInfoTile(
              icon: Icons.calendar_today_outlined,
              title: 'Account Created',
              value: _formatDate(user.metadata.creationTime),
            ),
            _buildInfoTile(
              icon: Icons.access_time,
              title: 'Last Sign In',
              value: _formatDate(user.metadata.lastSignInTime),
            ),
            // _buildInfoTile(
            //   icon: Icons.verified_user_outlined,
            //   title: 'Email Verified',
            //   value: user.emailVerified ? 'Yes' : 'No',
            //   valueColor: user.emailVerified ? Colors.green : Colors.orange,
            // ),
            const SizedBox(height: 32),

            // Appearance Section
            _buildSectionTitle('Appearance'),
            const SizedBox(height: 12),
            _buildSwitchTile(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Enable dark mode',
              value: ref.watch(themeProvider) == ThemeMode.dark,
              onChanged: (value) =>
                  ref.read(themeProvider.notifier).toggleTheme(),
            ),
            const SizedBox(height: 32),

            // Actions Section
            _buildSectionTitle('Actions'),
            const SizedBox(height: 12),

            // // Change Password
            // _buildActionTile(
            //   icon: Icons.lock_reset,
            //   title: 'Reset Password',
            //   subtitle: 'Send password reset email',
            //   onTap: () => _sendPasswordReset(context, ref, user.email),
            // ),

            // Sign Out
            _buildActionTile(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Sign out of your account',
              iconColor: Colors.red,
              onTap: () => _signOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, color: valueColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: iconColor ?? Colors.blueAccent),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _sendPasswordReset(
    BuildContext context,
    WidgetRef ref,
    String? email,
  ) async {
    if (email == null) return;

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        // AuthWrapper in main.dart will automatically redirect to LoginScreen
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.hardEdge,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(icon, color: Colors.blueAccent),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueAccent,
      ),
    );
  }
}
