import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter/material.dart';

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

  /// Bottom nav / navigation rail — release builds expose exactly these three.
  static const List<PrimaryDestination> shellValues = [
    PrimaryDestination.record,
    PrimaryDestination.archive,
    PrimaryDestination.account,
  ];

  int get shellIndex => shellValues.indexOf(this);

  static PrimaryDestination fromShellIndex(int index) {
    if (index < 0 || index >= shellValues.length) return record;
    return shellValues[index];
  }

  static PrimaryDestination? fromRoute(String route) {
    for (final destination in shellValues) {
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
final accountBranchNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'accountBranchNavigator',
);

final primaryBranchNavigatorKeys =
    <PrimaryDestination, GlobalKey<NavigatorState>>{
      PrimaryDestination.record: recordBranchNavigatorKey,
      PrimaryDestination.archive: archiveBranchNavigatorKey,
      PrimaryDestination.account: accountBranchNavigatorKey,
    };
