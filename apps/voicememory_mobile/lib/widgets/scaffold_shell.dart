import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/production_navigation.dart';
import '../theme/app_theme.dart';
import 'trust_banner.dart';

class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({
    super.key,
    required this.title,
    required this.body,
    this.showTrustBanner = !kReleaseMode,
    this.actions,
  });

  final String title;
  final Widget body;
  final bool showTrustBanner;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: const _AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTrustBanner) const TrustBanner(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final routes = <(String, String, IconData)>[
      ('/', 'Home', Icons.home_outlined),
      ('/onboarding', 'Onboarding', Icons.waving_hand_outlined),
      ('/record', 'Record', Icons.mic_none),
      ('/journal', 'Journal', Icons.book_outlined),
      ('/memory', 'Memory', Icons.auto_awesome_outlined),
      ('/search', 'Search', Icons.search),
      ('/pricing', 'Pricing', Icons.payments_outlined),
      ('/account', 'Account', Icons.person_outline),
      ('/export', 'Export', Icons.download_outlined),
      ('/delete-account', 'Delete account', Icons.delete_outline),
      ('/settings', 'Settings', Icons.settings_outlined),
    ].where((r) => ProductionNavigation.isNavRouteVisible(r.$1)).toList();
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ArchiveMe',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          for (final r in routes)
            ListTile(
              leading: Icon(r.$3),
              title: Text(r.$2),
              onTap: () {
                Navigator.pop(context);
                context.go(r.$1);
              },
            ),
        ],
      ),
    );
  }
}
