import 'package:archiveme_mobile/router/route_catalog.dart';

/// What a palette row does after it is chosen.
enum ArchiveCommandKind { navigate, toggleTheme }

/// One keyboard-reachable action in the command palette.
class ArchiveCommand {
  const ArchiveCommand({
    required this.id,
    required this.title,
    required this.route,
    required this.subtitle,
    this.keywords = const [],
    this.kind = ArchiveCommandKind.navigate,
  });

  final String id;
  final String title;
  final String route;
  final String subtitle;
  final List<String> keywords;
  final ArchiveCommandKind kind;

  bool matches(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = [
      title,
      subtitle,
      route,
      ...keywords,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

/// Navigation and capture actions offered from Cmd/Ctrl+K.
abstract final class ArchiveCommandCatalog {
  ArchiveCommandCatalog._();

  static const commands = <ArchiveCommand>[
    ArchiveCommand(
      id: 'create_entry',
      title: 'Create Entry',
      subtitle: 'Start a new moment',
      route: RouteCatalog.recordHome,
      keywords: ['new', 'record', 'journal'],
    ),
    ArchiveCommand(
      id: 'search_archives',
      title: 'Search Archives',
      subtitle: 'Find a saved moment',
      route: RouteCatalog.archiveHome,
      keywords: ['search', 'find'],
    ),
    ArchiveCommand(
      id: 'toggle_theme',
      title: 'Toggle Theme',
      subtitle: 'Switch light and dark',
      route: '',
      kind: ArchiveCommandKind.toggleTheme,
      keywords: ['dark', 'light', 'appearance'],
    ),
    ArchiveCommand(
      id: 'export_data',
      title: 'Export Data',
      subtitle: 'Take a copy of saved moments',
      route: '/export',
      keywords: ['download', 'pdf', 'backup'],
    ),
    ArchiveCommand(
      id: 'open_insights',
      title: 'Open Insights',
      subtitle: 'Weekly synthesis and patterns',
      route: '/theories',
      keywords: ['insights', 'patterns', 'weekly'],
    ),
    ArchiveCommand(
      id: 'new_moment',
      title: 'New moment',
      subtitle: 'Start a voice capture',
      route: RouteCatalog.recordHome,
      keywords: ['record', 'create', 'voice'],
    ),
    ArchiveCommand(
      id: 'type_moment',
      title: 'Type a moment',
      subtitle: 'Write instead of speaking',
      route: '/quick-capture',
      keywords: ['write', 'text', 'entry', 'create'],
    ),
    ArchiveCommand(
      id: 'archive',
      title: 'Open archive',
      subtitle: 'Saved moments',
      route: RouteCatalog.archiveHome,
      keywords: ['home', 'saved'],
    ),
    ArchiveCommand(
      id: 'account',
      title: 'Account',
      subtitle: 'Profile and privacy controls',
      route: RouteCatalog.accountHome,
      keywords: ['profile'],
    ),
    ArchiveCommand(
      id: 'settings',
      title: 'Settings',
      subtitle: 'Preferences',
      route: '/settings',
      keywords: ['preferences'],
    ),
    ArchiveCommand(
      id: 'theories',
      title: 'Working theories',
      subtitle: 'How ideas are tracking',
      route: '/theories',
      keywords: ['ideas'],
    ),
    ArchiveCommand(
      id: 'export',
      title: 'Export',
      subtitle: 'Take a copy of saved moments',
      route: '/export',
      keywords: ['download', 'backup'],
    ),
  ];

  static List<ArchiveCommand> filter(String query) {
    return [
      for (final command in commands)
        if (command.matches(query)) command,
    ];
  }
}
