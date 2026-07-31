import 'package:flutter/material.dart';

import 'route_catalog.dart';

/// The only destinations that own branches in the primary indexed shell.
enum PrimaryDestination {
  record(
    route: RouteCatalog.recordHome,
    label: 'Record',
    accessibilityLabel: 'Record',
    icon: Icons.mic_none_outlined,
    selectedIcon: Icons.mic,
    screenLabel: 'Record screen',
  ),
  archive(
    route: RouteCatalog.archiveHome,
    label: 'Archive',
    accessibilityLabel: 'Archive',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    screenLabel: 'Archive screen',
  ),
  changes(
    route: RouteCatalog.changesHome,
    label: 'Changes',
    accessibilityLabel: 'Changes',
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline,
    screenLabel: 'Changes screen',
  ),
  account(
    route: RouteCatalog.accountHome,
    label: 'Account',
    accessibilityLabel: 'Account',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    screenLabel: 'Account screen',
  );

  const PrimaryDestination({
    required this.route,
    required this.label,
    required this.accessibilityLabel,
    required this.icon,
    required this.selectedIcon,
    required this.screenLabel,
  });

  final String route;
  final String label;
  final String accessibilityLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String screenLabel;

  static PrimaryDestination fromIndex(int index) {
    if (index < 0 || index >= values.length) return record;
    return values[index];
  }

  static PrimaryDestination? fromRoute(String route) {
    for (final destination in values) {
      if (destination.route == route) return destination;
    }
    return null;
  }
}

final recordBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'recordBranchNavigator',
);
final archiveBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'archiveBranchNavigator',
);
final changesBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'changesBranchNavigator',
);
final accountBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'accountBranchNavigator',
);

final primaryBranchNavigatorKeys =
    <PrimaryDestination, GlobalKey<NavigatorState>>{
      PrimaryDestination.record: recordBranchNavigatorKey,
      PrimaryDestination.archive: archiveBranchNavigatorKey,
      PrimaryDestination.changes: changesBranchNavigatorKey,
      PrimaryDestination.account: accountBranchNavigatorKey,
    };
