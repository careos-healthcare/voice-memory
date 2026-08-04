import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';
import 'blind_spots_screen.dart';
import 'identity_screen.dart';
import 'life_chapters_screen.dart';

/// A single, evidence-backed workspace for understanding the self over time.
class SelfDiscoveryCenterScreen extends StatelessWidget {
  const SelfDiscoveryCenterScreen({super.key, this.initialTab = 0});

  static const route = '/self-discovery';

  final int initialTab;

  static int tabIndexFor(String? tab) => switch (tab) {
    'identity' => 1,
    'life-chapters' => 2,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final selectedTab = initialTab < 0
        ? 0
        : initialTab > 2
        ? 2
        : initialTab;
    return DefaultTabController(
      length: 3,
      initialIndex: selectedTab,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          title: const Text('Self-discovery'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.visibility_outlined), text: 'Blind spots'),
              Tab(icon: Icon(Icons.fingerprint_outlined), text: 'Identity'),
              Tab(icon: Icon(Icons.timeline_outlined), text: 'Life chapters'),
            ],
          ),
        ),
        body: AccessiblePrimarySurface(
          label: 'Self-discovery center',
          child: TabBarView(
            children: [
              Semantics(
                container: true,
                label: 'Blind spots view',
                child: BlindSpotsView(),
              ),
              Semantics(
                container: true,
                label: 'Identity view',
                child: IdentityView(),
              ),
              Semantics(
                container: true,
                label: 'Life chapters view',
                child: LifeChaptersView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
