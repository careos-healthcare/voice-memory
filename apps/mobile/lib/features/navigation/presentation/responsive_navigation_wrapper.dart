import 'package:archiveme_mobile/core/theme/responsive_breakpoints.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Bottom tabs on a phone, and a collapsible sidebar from tablet width up.
class ResponsiveNavigationWrapper extends StatefulWidget {
  const ResponsiveNavigationWrapper({
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final Widget body;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<ResponsiveNavigationWrapper> createState() =>
      _ResponsiveNavigationWrapperState();
}

class _ResponsiveNavigationWrapperState
    extends State<ResponsiveNavigationWrapper> {
  var _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (ResponsiveBreakpoints.isMobile(width)) {
          return Scaffold(
            body: widget.body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onSelected,
              destinations: widget.destinations,
            ),
          );
        }
        final extended = ResponsiveBreakpoints.isDesktop(width) && !_collapsed;
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                extended: extended,
                selectedIndex: widget.selectedIndex,
                destinations: widget.destinations,
                onSelected: widget.onSelected,
                onToggle: () => setState(() => _collapsed = !_collapsed),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: widget.body),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.extended,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.onToggle,
  });

  final bool extended;
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(hoverColor: AppColors.accentLight),
      child: FocusTraversalGroup(
        child: Column(
          children: [
            SizedBox(
              height: ResponsiveBreakpoints.desktopTouchTarget,
              width: ResponsiveBreakpoints.desktopTouchTarget,
              child: IconButton(
                key: const Key('nav_collapse_toggle'),
                padding: EdgeInsets.zero,
                onPressed: onToggle,
                icon: Icon(extended ? Icons.menu_open : Icons.menu),
              ),
            ),
            Expanded(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                extended: extended,
                minWidth: ResponsiveBreakpoints.desktopTouchTarget,
                onDestinationSelected: onSelected,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon:
                          destination.selectedIcon ?? destination.icon,
                      label: Text(destination.label),
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
