import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/production_navigation.dart';
import '../../features/feature_discovery/contextual_feature_discovery_banner.dart';
import '../../features/v1_interface/archive_secondary_nav_gates.dart';
import '../../services/app_services.dart';
import '../../services/feature_discovery/feature_discovery_service.dart';
import '../../theme/app_spacing.dart';

/// Secondary Archive links, including one grouped entry to advanced tools.
class ArchiveSecondaryNavLinks extends StatelessWidget {
  const ArchiveSecondaryNavLinks({super.key, required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    if (!ArchiveSecondaryNavGates.showSecondaryLinks(entryCount: entryCount)) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    if (AppServices.isInitialized) {
      children.add(
        ContextualFeatureDiscoveryBanner(
          service: FeatureDiscoveryService(prefs: AppServices.instance.prefs),
          discoveryContext: FeatureDiscoveryContext(
            moment: FeatureDiscoveryMoment.dashboard,
            entryCount: entryCount,
          ),
        ),
      );
    }
    void addLink({
      required Key key,
      required String route,
      required String label,
    }) {
      if (!ProductionNavigation.isNavRouteVisible(route)) return;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.sm));
      }
      children.add(
        Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
            child: OutlinedButton(
              key: key,
              onPressed: () => context.push(route),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    addLink(
      key: const Key('archive_secondary_tools'),
      route: '/archive-tools',
      label: 'Explore Life Story & Archive Intelligence',
    );

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('archive_secondary_nav_links'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
