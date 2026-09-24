import 'package:archiveme_mobile/core/theme/responsive_breakpoints.dart';
import 'package:archiveme_mobile/desktop/desktop_window_host.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_badge.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_shell.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/router/primary_navigation_controller.dart';
import 'package:archiveme_mobile/router/primary_navigation_provider.dart';
import 'package:archiveme_mobile/router/record_navigation_activity_controller.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/widgets/accessibility/accessible_primary_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class MainShell extends ConsumerWidget {
  const MainShell({
    required this.navigationShell,
    super.key,
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

  void _goBranch(
    BuildContext context,
    WidgetRef ref,
    PrimaryDestination destination,
  ) {
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
    navigationShell.goBranch(
      destination.shellIndex,
      initialLocation: reselected,
    );
    _primaryController.activate(destination, reselected: reselected);
    ref
        .read(primaryNavigationProvider.notifier)
        .activate(destination, reselected: reselected);
  }

  bool _activeBranchCanPop(PrimaryDestination destination) =>
      primaryBranchNavigatorKeys[destination]?.currentState?.canPop() ?? false;

  void _handleBlockedPop(
    BuildContext context,
    WidgetRef ref,
    PrimaryDestination destination,
  ) {
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
    if (destination != PrimaryDestination.archive) {
      _goBranch(context, ref, PrimaryDestination.archive);
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

  Widget _phoneNavigation(
    BuildContext context,
    WidgetRef ref,
    PrimaryDestination selected,
  ) {
    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: NavigationBar(
        selectedIndex: selected.shellIndex,
        onDestinationSelected: (index) =>
            _goBranch(context, ref, PrimaryDestination.fromShellIndex(index)),
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
    WidgetRef ref,
    PrimaryDestination selected, {
    required bool extended,
  }) {
    return Semantics(
      container: true,
      label: 'Primary navigation',
      child: NavigationRail(
        selectedIndex: selected.shellIndex,
        extended: extended,
        minWidth: ResponsiveBreakpoints.desktopTouchTarget,
        onDestinationSelected: (index) =>
            _goBranch(context, ref, PrimaryDestination.fromShellIndex(index)),
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

  void _startVoiceCapture(BuildContext context) {
    context.push(RouteCatalog.recordHome);
  }

  Widget _captureButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _startVoiceCapture(context),
      icon: const Icon(Icons.mic),
      label: const Text('Record'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(primaryNavigationProvider);
    final selected = PrimaryDestination.fromShellIndex(
      navigationShell.currentIndex,
    );
    if (_primaryController.activeDestination != selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _primaryController.activate(selected);
        ref.read(primaryNavigationProvider.notifier).activate(selected);
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
            (branchCanPop || selected == PrimaryDestination.archive),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleBlockedPop(context, ref, selected);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final body = SyncStatusShell(
              child: AccessiblePrimarySurface(
                label: selected.screenLabel,
                child: navigationShell,
              ),
            );
            if (ResponsiveBreakpoints.isMobile(constraints.maxWidth)) {
              return Scaffold(
                backgroundColor: AppColors.backgroundPrimary,
                floatingActionButton: _captureButton(context),
                body: Column(
                  children: [
                    const SyncStatusBadgeSlot(),
                    Expanded(child: body),
                  ],
                ),
                bottomNavigationBar: _phoneNavigation(context, ref, selected),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.backgroundPrimary,
              floatingActionButton: _captureButton(context),
              body: Column(
                children: [
                  DesktopWindowHost.chrome(),
                  const SyncStatusBadgeSlot(),
                  Expanded(
                    child: Row(
                      children: [
                        _railNavigation(
                          context,
                          ref,
                          selected,
                          extended: ResponsiveBreakpoints.isDesktop(
                            constraints.maxWidth,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final PrimaryNavigationController globalPrimaryNavigationController =
    primaryNavigationController;
final RecordNavigationActivityController
globalRecordNavigationActivityController = recordNavigationActivityController;
