import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Focused V1 account destination.
///
/// Advanced labs and experimental feature settings intentionally do not enter
/// the production import graph through this screen.
class V1AccountScreen extends StatelessWidget {
  const V1AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your private archive',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage access, privacy, exports, and your ArchiveMe subscription.',
        ),
        const SizedBox(height: 16),
        _RouteTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          route: '/settings',
        ),
        _RouteTile(
          icon: Icons.lock_outline,
          title: 'Privacy and security',
          route: '/privacy-trust-centre',
        ),
        _RouteTile(
          icon: Icons.workspace_premium_outlined,
          title: 'ArchiveMe Pro',
          route: '/subscription',
        ),
        _RouteTile(
          icon: Icons.download_outlined,
          title: 'Export archive',
          route: '/export',
        ),
        _RouteTile(
          icon: Icons.help_outline,
          title: 'Support',
          route: '/support-feedback',
        ),
        const Divider(),
        _RouteTile(
          icon: Icons.person_add_alt,
          title: 'Create account',
          route: '/account/create',
        ),
        _RouteTile(
          icon: Icons.login,
          title: 'Sign in',
          route: '/account/sign-in',
        ),
        _RouteTile(
          icon: Icons.delete_outline,
          title: 'Delete account',
          route: '/delete-account',
        ),
      ],
    ),
  );
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}
