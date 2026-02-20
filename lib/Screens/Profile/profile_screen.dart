import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dryvmobapp/Providers/user_provider.dart';
import 'package:dryvmobapp/theme/app_colors.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: userAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
        error: (err, _) {
          return _ErrorState(
            message: '$err',
            onRetry: () => ref.read(currentUserProvider.notifier).reload(),
          );
        },
        data: (user) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(currentUserProvider.notifier).reload(),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _HeaderHero(
                  name: user.name,
                  email: user.email,
                  verified: user.emailVerifiedAt != null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Profile Details',
                        child: Column(
                          children: [
                            _InfoLine(
                              icon: Icons.badge_outlined,
                              label: 'Name',
                              value: user.name,
                            ),
                            const Divider(height: 16),
                            _InfoLine(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: user.email,
                            ),
                            const Divider(height: 16),
                            _InfoLine(
                              icon: Icons.verified_outlined,
                              label: 'Email Verified',
                              value: user.emailVerifiedAt == null
                                  ? 'No'
                                  : 'Yes',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Account Settings',
                        child: Column(
                          children: const [
                            _ActionTile(
                              icon: Icons.lock_reset_outlined,
                              title: 'Password Reset',
                              subtitle: 'Coming soon',
                            ),
                            Divider(height: 10),
                            _ActionTile(
                              icon: Icons.help_outline,
                              title: 'Forgot Password',
                              subtitle: 'Coming soon',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Analytics',
                        child: Row(
                          children: const [
                            Expanded(
                              child: _StatCard(
                                value: '—',
                                label: 'Saved\nLocations',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '—',
                                label: 'Reported\nFlooded Roads',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '—',
                                label: 'Requested\nSafe Route',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Notifications Preference',
                        child: const _ActionTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Manage Notifications',
                          subtitle: 'Coming soon',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Report a Problem',
                        child: const _ActionTile(
                          icon: Icons.report_problem_outlined,
                          title: 'Send Feedback',
                          subtitle: 'Coming soon',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderHero extends StatelessWidget {
  final String name;
  final String email;
  final bool verified;

  const _HeaderHero({
    required this.name,
    required this.email,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Your Name' : name;
    final displayEmail = email.trim().isEmpty ? 'your@email.com' : email;
    final initial =
        (displayName.trim().isNotEmpty ? displayName.trim()[0] : '?')
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.blue.withValues(alpha: 0.92)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent.withValues(alpha: 0.95),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Pill(
                    text: verified ? 'Verified' : 'Unverified',
                    icon: verified ? Icons.verified : Icons.info_outline,
                    background: Colors.white.withValues(alpha: 0.16),
                    foreground: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.blue.withValues(alpha: 0.85), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBlue.withValues(alpha: 0.70),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.trim().isEmpty ? '—' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.darkBlue.withValues(alpha: 0.65),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.blue.withValues(alpha: 0.75),
      ),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coming soon.')));
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBlue.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: foreground,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load profile',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
