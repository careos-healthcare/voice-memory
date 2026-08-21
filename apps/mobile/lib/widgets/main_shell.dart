import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_shell.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/accessibility/accessible_primary_surface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class MainShell extends StatelessWidget {
  const MainShell({
    required this.navigationShell, super.key,
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
        destination.shellIndex != navigationShell.currentIndex) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.finishRecordingFirst),
          ),
        );
      return;
    }
    final reselected = destination.shellIndex == navigationShell.currentIndex;
    navigationShell.goBranch(destination.shellIndex, initialLocation: reselected);
    _primaryController.activate(destination, reselected: reselected);
  }

  bool _activeBranchCanPop(PrimaryDestination destination) =>
      primaryBranchNavigatorKeys[destination]?.currentState?.canPop() ?? false;

  void _handleBlockedPop(BuildContext context, PrimaryDestination destination) {
    if (_recordActivityController.isNavigationLocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.finishRecordingFirst),
          ),
        );
      return;
    }
    final navigator = primaryBranchNavigatorKeys[destination]?.currentState;
    if (navigator?.canPop() ?? false) {
      unawaited(navigator!.maybePop());
      return;
    }
    if (destination != PrimaryDestination.record) {
      _goBranch(context, PrimaryDestination.record);
    }
  }

  Widget _destinationSemantics({
    required PrimaryDestination destination,
    required bool selected,
    required Widget child,
  }) {
    final position = destination.shellIndex + 1;
    final total = PrimaryDestination.shellValues.length;
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${destination.accessibilityLabel}, tab $position of $total'
          '${selected ? ', selected' : ''}',
      child: child,
    );
  }

  Widget _phoneNavigation(BuildContext context, PrimaryDestination selected) {
    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: NavigationBar(
        selectedIndex: selected.shellIndex,
        onDestinationSelected: (index) =>
            _goBranch(context, PrimaryDestination.fromShellIndex(index)),
        destinations: [
          for (final destination in PrimaryDestination.shellValues)
            _destinationSemantics(
              destination: destination,
              selected: destination == selected,
              child: NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
                tooltip: destination.accessibilityLabel,
              ),
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
        selectedIndex: selected.shellIndex,
        extended: extended,
        onDestinationSelected: (index) =>
            _goBranch(context, PrimaryDestination.fromShellIndex(index)),
        destinations: [
          for (final destination in PrimaryDestination.shellValues)
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
    final selected =
        PrimaryDestination.fromShellIndex(navigationShell.currentIndex);
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
            final body = SyncStatusShell(
              child: AccessiblePrimarySurface(
                label: selected.screenLabel,
                child: navigationShell,
              ),
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

final PrimaryNavigationController globalPrimaryNavigationController = primaryNavigationController;
final RecordNavigationActivityController globalRecordNavigationActivityController =
    recordNavigationActivityController;
