import 'package:archiveme_mobile/record/start_here_visibility.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/record/start_here_recording_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Loads journal state and renders [StartHereRecordingSection] on empty surfaces.
class StartHereLoader extends StatefulWidget {
  const StartHereLoader({required this.surface, super.key});

  final String surface;

  @override
  State<StartHereLoader> createState() => _StartHereLoaderState();
}

class _StartHereLoaderState extends State<StartHereLoader> {
  int _recordingCount = 0;
  bool _firstArchiveMilestoneCompleted = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final all = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _recordingCount = all.length;
      _firstArchiveMilestoneCompleted =
          StartHereVisibility.hasCompletedFirstArchiveMilestone(all);
      _loaded = true;
    });
  }

  void _onPromptSelected(String prompt) {
    final encoded = Uri.encodeComponent(prompt);
    context.go('/record?prompt=$encoded&autostart=1');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return StartHereRecordingSection(
      recordingCount: _recordingCount,
      firstArchiveMilestoneCompleted: _firstArchiveMilestoneCompleted,
      onPromptSelected: _onPromptSelected,
      surface: widget.surface,
    );
  }
}