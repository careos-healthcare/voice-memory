import 'package:flutter/material.dart';

import '../../features/memory/clean_slate_prompt_store.dart';
import '../../features/memory/entry_memory_mode.dart';
import '../../features/memory/memory_control_model.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/memory/topic_shift_decision.dart';
import '../../features/memory/topic_shift_guard.dart';
import '../../features/pressure_retention/pressure_check_in_record.dart';
import '../../features/pressure_retention/pressure_check_in_store.dart';
import '../../services/app_services.dart';
import 'clean_slate_prompt_card.dart';

/// Loads pressure records and shows [CleanSlatePromptCard] when warranted.
class CleanSlatePromptSection extends StatefulWidget {
  const CleanSlatePromptSection({
    super.key,
    required this.entryCount,
    this.cardType = MemoryCardType.threadReturn,
    this.source = 'record',
  });

  final int entryCount;
  final MemoryCardType cardType;
  final String source;

  @override
  State<CleanSlatePromptSection> createState() =>
      _CleanSlatePromptSectionState();
}

class _CleanSlatePromptSectionState extends State<CleanSlatePromptSection> {
  TopicShiftDecision? _decision;
  var _promptSeenTracked = false;

  @override
  void initState() {
    super.initState();
    CleanSlatePromptStore.noteSessionStart();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CleanSlatePromptSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryCount != widget.entryCount) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (widget.entryCount == 0 ||
        MemoryScopePolicy.scope == MemoryScope.off ||
        EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate) {
      if (!mounted) return;
      setState(() {
        _decision = null;
      });
      return;
    }

    List<PressureCheckInRecord> records = const [];
    if (AppServices.isInitialized) {
      records = await PressureCheckInStore.instance().loadAll();
    }

    final decision = TopicShiftGuard.evaluate(
      entryCount: widget.entryCount,
      records: records,
      cardType: widget.cardType,
      source: widget.source,
    );

    if (!mounted) return;
    setState(() {
      _decision = decision;
    });

    if (decision.shouldPrompt && !_promptSeenTracked) {
      _promptSeenTracked = true;
      CleanSlatePromptStore.notePromptSeen(
        entryCount: widget.entryCount,
        decision: decision,
        source: widget.source,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision == null || !decision.shouldPrompt) {
      return const SizedBox.shrink(key: Key('clean_slate_prompt_hidden'));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CleanSlatePromptCard(
        decision: decision,
        entryCount: widget.entryCount,
        cardType: widget.cardType,
        source: widget.source,
        onChanged: () {
          setState(() => _decision = null);
          _reload();
        },
      ),
    );
  }
}
