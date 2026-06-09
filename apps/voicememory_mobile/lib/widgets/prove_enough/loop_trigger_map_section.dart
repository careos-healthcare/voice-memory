import 'package:flutter/material.dart';

import '../../features/loop_mode/loop_mode_coordinator.dart';
import '../../features/loop_mode/loop_mode_model.dart';
import '../../features/prove_enough/loop_trigger_map_engine.dart';
import '../../features/prove_enough/loop_trigger_map_model.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';
import 'loop_trigger_map_card.dart';

/// Loads journal entries and renders the prove_enough loop trigger map.
class LoopTriggerMapSection extends StatefulWidget {
  const LoopTriggerMapSection({
    super.key,
    this.entries,
    this.activeLoop,
  });

  final List<JournalEntry>? entries;
  final LoopMode? activeLoop;

  @override
  State<LoopTriggerMapSection> createState() => _LoopTriggerMapSectionState();
}

class _LoopTriggerMapSectionState extends State<LoopTriggerMapSection> {
  static const _engine = LoopTriggerMapEngine();

  LoopTriggerMapModel? _model;
  bool _loading = true;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    LoopMode? loop = widget.activeLoop;
    if (loop == null && AppServices.isInitialized) {
      loop = await LoopModeCoordinator.loadActive();
    }

    if (loop?.isProveEnough != true) {
      if (!mounted) return;
      setState(() {
        _show = false;
        _loading = false;
      });
      return;
    }

    List<JournalEntry> entries = widget.entries ?? const [];
    if (entries.isEmpty && AppServices.isInitialized) {
      entries = await AppServices.instance.journalStore.loadAll();
    }

    final model = _engine.build(entries);
    if (!mounted) return;
    setState(() {
      _model = model;
      _show = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show || _model == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoopTriggerMapCard(model: _model!),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
