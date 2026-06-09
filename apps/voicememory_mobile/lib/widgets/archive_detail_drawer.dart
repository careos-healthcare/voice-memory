import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/production_navigation.dart';
import '../theme/app_theme.dart';

/// More archive surfaces — opened from Archive menu.
class ArchiveDetailDrawer extends StatelessWidget {
  const ArchiveDetailDrawer({super.key, this.sheet = false});

  /// When true, content is shown in a modal bottom sheet (scrollable, intrinsic height).
  final bool sheet;

  static const items = <({String label, String route})>[
    (label: 'Archive Analyst', route: '/archive-analyst'),
    (label: 'Life Chapters', route: '/archive-life-chapters'),
    (label: 'Identity', route: '/archive-identity'),
    (label: 'Search', route: '/search'),
    (label: 'Reflection Log', route: '/journal'),
    (label: 'Pattern Review', route: '/blind-spots'),
  ];

  static List<({String label, String route})> visibleItems() {
    return items
        .where((item) => ProductionNavigation.isNavRouteVisible(item.route))
        .toList();
  }

  static void open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const ArchiveDetailDrawer(sheet: true),
    );
  }

  static const _padding = EdgeInsets.fromLTRB(16, 12, 16, 24);

  static const _sheetSubtitle =
      'Reflection log and pattern review — deeper views of your archive.';

  List<Widget> _children(BuildContext context) {
    return [
      const Text(
        'More from your archive',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.foreground,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        _sheetSubtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.4),
      ),
      const SizedBox(height: 16),
      for (final item in visibleItems())
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            item.label,
            style: const TextStyle(color: AppTheme.foreground, fontSize: 15),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.muted, size: 20),
          onTap: () {
            Navigator.of(context).pop();
            context.push(item.route);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final children = _children(context);

    if (sheet) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: _padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: _padding,
        children: children,
      ),
    );
  }
}
