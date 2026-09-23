import 'package:archiveme_mobile/features/desktop/desktop_shortcut_manager.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Wide-window split: navigation, moment stream, and the entity inspector.
class DesktopMasterDetailLayout extends StatelessWidget {
  const DesktopMasterDetailLayout({
    required this.navigation,
    required this.timeline,
    required this.inspector,
    super.key,
    this.breakpoint = wideBreakpoint,
  });

  /// Viewports wider than this use the three-column layout.
  static const double wideBreakpoint = 840;

  final Widget navigation;
  final Widget timeline;
  final Widget inspector;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > breakpoint;
          final navWidth = (constraints.maxWidth * 0.22).clamp(200.0, 280.0);
          final inspectorWidth = (constraints.maxWidth * 0.30).clamp(
            260.0,
            420.0,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PersistentPane(
                open: wide,
                width: navWidth,
                child: navigation,
              ),
              Expanded(child: timeline),
              _PersistentPane(
                open: wide,
                width: inspectorWidth,
                child: inspector,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Keeps a side pane mounted so resize and rotation do not drop its state.
class _PersistentPane extends StatelessWidget {
  const _PersistentPane({
    required this.open,
    required this.width,
    required this.child,
  });

  final bool open;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !open,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: AppTokens.neutral200),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One sidebar destination. The wide layout keeps the same three sections.
class DesktopNavDestination {
  const DesktopNavDestination({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Left column for Record, Archive, and Account.
class DesktopNavigationSidebar extends StatelessWidget {
  const DesktopNavigationSidebar({required this.destinations, super.key});

  final List<DesktopNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('desktop_nav_sidebar'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing3),
      children: [
        for (final destination in destinations)
          ListTile(
            key: Key('desktop_nav_${destination.label}'),
            selected: destination.selected,
            title: Text(destination.label),
            onTap: destination.onTap,
          ),
      ],
    );
  }
}

/// A moment shown in the center stream.
class DesktopMoment {
  const DesktopMoment({
    required this.id,
    required this.title,
    required this.transcript,
    this.entityNames = const [],
    this.hasAudio = false,
  });

  final String id;
  final String title;
  final String transcript;
  final List<String> entityNames;
  final bool hasAudio;
}

/// Center column: semantic search and the moment stream.
class DesktopMomentStream extends StatelessWidget {
  const DesktopMomentStream({
    required this.moments,
    required this.selectedId,
    required this.onSelect,
    super.key,
    this.searchFocus,
  });

  final List<DesktopMoment> moments;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final FocusNode? searchFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('desktop_moment_stream'),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTokens.spacing3),
          child: TextField(
            key: const Key('semantic_search_field'),
            focusNode: searchFocus,
            decoration: const InputDecoration(
              hintText:
                  'What did I say about the solar panel installation last month?',
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final moment in moments)
                ListTile(
                  key: Key('desktop_moment_${moment.id}'),
                  selected: moment.id == selectedId,
                  title: Text(moment.title),
                  subtitle: Text(moment.transcript),
                  onTap: () => onSelect(moment.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Right column: entities for the selected moment and its audio control.
class DesktopEntityInspector extends StatelessWidget {
  const DesktopEntityInspector({
    required this.moment,
    required this.playback,
    super.key,
  });

  final DesktopMoment? moment;
  final DesktopPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final current = moment;
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        return ListView(
          key: const Key('desktop_entity_inspector'),
          padding: const EdgeInsets.all(AppTokens.spacing3),
          children: [
            Text(
              current?.title ?? 'Select a moment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spacing2),
            const Text('Entities'),
            if (current == null || current.entityNames.isEmpty)
              const Text('No linked entities')
            else
              Wrap(
                spacing: AppTokens.spacing2,
                children: [
                  for (final name in current.entityNames)
                    Chip(
                      key: Key('desktop_entity_$name'),
                      label: Text(name),
                    ),
                ],
              ),
            const SizedBox(height: AppTokens.spacing4),
            DesktopAudioPlayer(
              enabled: current?.hasAudio ?? false,
              playing: playback.playing && playback.momentId == current?.id,
              onToggle: current == null || !current.hasAudio
                  ? null
                  : () {
                      playback
                        ..select(current.id, hasAudio: true)
                        ..toggle();
                    },
            ),
          ],
        );
      },
    );
  }
}

/// Play and pause for the selected recording.
class DesktopAudioPlayer extends StatelessWidget {
  const DesktopAudioPlayer({
    required this.enabled,
    required this.playing,
    super.key,
    this.onToggle,
  });

  final bool enabled;
  final bool playing;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const Key('desktop_audio_player'),
        onPressed: enabled ? onToggle : null,
        child: Text(playing ? 'Pause' : 'Play'),
      ),
    );
  }
}

/// Selects a moment and keeps that choice when the window changes size.
class DesktopArchiveColumns extends StatefulWidget {
  const DesktopArchiveColumns({
    required this.moments,
    required this.destinations,
    required this.playback,
    super.key,
    this.searchFocus,
    this.breakpoint = DesktopMasterDetailLayout.wideBreakpoint,
  });

  final List<DesktopMoment> moments;
  final List<DesktopNavDestination> destinations;
  final DesktopPlaybackController playback;
  final FocusNode? searchFocus;
  final double breakpoint;

  @override
  State<DesktopArchiveColumns> createState() => _DesktopArchiveColumnsState();
}

class _DesktopArchiveColumnsState extends State<DesktopArchiveColumns> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final first = widget.moments.isEmpty ? null : widget.moments.first;
    _selectedId = first?.id;
    widget.playback.select(_selectedId, hasAudio: first?.hasAudio ?? false);
  }

  DesktopMoment? get _selected {
    for (final moment in widget.moments) {
      if (moment.id == _selectedId) return moment;
    }
    return null;
  }

  void _select(String id) {
    DesktopMoment? moment;
    for (final candidate in widget.moments) {
      if (candidate.id == id) moment = candidate;
    }
    setState(() => _selectedId = id);
    widget.playback.select(id, hasAudio: moment?.hasAudio ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopMasterDetailLayout(
      breakpoint: widget.breakpoint,
      navigation: DesktopNavigationSidebar(destinations: widget.destinations),
      timeline: DesktopMomentStream(
        moments: widget.moments,
        selectedId: _selectedId,
        searchFocus: widget.searchFocus,
        onSelect: _select,
      ),
      inspector: DesktopEntityInspector(
        moment: _selected,
        playback: widget.playback,
      ),
    );
  }
}
