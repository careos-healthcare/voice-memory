import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/primary_destination.dart';
import '../router/primary_navigation_controller.dart';
import '../router/record_navigation_activity_controller.dart';
import '../theme/app_colors.dart';
import 'accessibility/accessible_primary_surface.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
    this.primaryNavigationController,
    this.recordNavigationActivityController,
  });

  final StatefulNavigationShell navigationShell;
  final PrimaryNavigationController? primaryNavigationController;
  final RecordNavigationActivityController? recordNavigationActivityController;

  PrimaryNavigationController get _primaryController =>
      primaryNavigationController ?? globalPrimaryNavigationController;

  RecordNavigationActivityController get _recordActivityController =>
      recordNavigationActivityController ??
      globalRecordNavigationActivityController;

  void _goBranch(BuildContext context, PrimaryDestination destination) {
    if (_recordActivityController.isNavigationLocked &&
        destination.index != navigationShell.currentIndex) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Finish or cancel the recording first.'),
          ),
        );
      return;
    }
    final reselected = destination.index == navigationShell.currentIndex;
    navigationShell.goBranch(destination.index, initialLocation: reselected);
    _primaryController.activate(destination, reselected: reselected);
  }

  bool _activeBranchCanPop(PrimaryDestination destination) =>
      primaryBranchNavigatorKeys[destination]?.currentState?.canPop() ?? false;

  void _handleBlockedPop(BuildContext context, PrimaryDestination destination) {
    if (_recordActivityController.isNavigationLocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Finish or cancel the recording first.'),
          ),
        );
      return;
    }
    final navigator = primaryBranchNavigatorKeys[destination]?.currentState;
    if (navigator?.canPop() ?? false) {
      navigator!.maybePop();
      return;
    }
    if (destination != PrimaryDestination.record) {
      _goBranch(context, PrimaryDestination.record);
    }
  }

  Widget _phoneNavigation(BuildContext context, PrimaryDestination selected) {
    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: NavigationBar(
        selectedIndex: selected.index,
        onDestinationSelected: (index) =>
            _goBranch(context, PrimaryDestination.fromIndex(index)),
        destinations: [
          for (final destination in PrimaryDestination.values)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
              tooltip: destination.accessibilityLabel,
            ),
        ],
      ),
    );
  }

  Widget _railNavigation(
    BuildContext context,
    PrimaryDestination selected, {
    required bool extended,
  }) {
    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: NavigationRail(
        selectedIndex: selected.index,
        extended: extended,
        onDestinationSelected: (index) =>
            _goBranch(context, PrimaryDestination.fromIndex(index)),
        destinations: [
          for (final destination in PrimaryDestination.values)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.label),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = PrimaryDestination.fromIndex(navigationShell.currentIndex);
    if (_primaryController.activeDestination != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _primaryController.activate(selected);
      });
    }
    final branchCanPop = _activeBranchCanPop(selected);
    return ListenableBuilder(
      listenable: Listenable.merge([
        _primaryController,
        _recordActivityController,
      ]),
      builder: (context, _) => PopScope<Object?>(
        canPop:
            !_recordActivityController.isNavigationLocked &&
            (branchCanPop || selected == PrimaryDestination.record),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleBlockedPop(context, selected);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final body = AccessiblePrimarySurface(
              label: selected.screenLabel,
              child: navigationShell,
            );
            if (constraints.maxWidth < 700) {
              return Scaffold(
                backgroundColor: AppColors.backgroundPrimary,
                body: body,
                bottomNavigationBar: _phoneNavigation(context, selected),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.backgroundPrimary,
              body: Row(
                children: [
                  _railNavigation(
                    context,
                    selected,
                    extended: constraints.maxWidth >= 1000,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final globalPrimaryNavigationController = primaryNavigationController;
final globalRecordNavigationActivityController =
    recordNavigationActivityController;
