import 'package:flutter/material.dart';

import '../features/archive_explanations/explanation_models.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import 'evidence_trail/why_am_i_seeing_this_button.dart';

/// Universal evidence-trail affordance on insight cards.
class ArchiveWhyButton extends StatelessWidget {
  const ArchiveWhyButton({
    super.key,
    required this.ref,
    this.entries,
    this.state,
    this.askPrompt,
    this.askCitedEntryIds,
    this.compact = false,
    this.surface = 'insight',
  });

  final ArchiveInsightRef ref;
  final List<JournalEntry>? entries;
  final ArchiveStateObjectV3? state;
  final String? askPrompt;
  final List<String>? askCitedEntryIds;
  final bool compact;
  final String surface;

  @override
  Widget build(BuildContext context) {
    return WhyAmISeeingThisForInsight(
      ref: ref,
      entries: entries,
      state: state,
      surface: surface,
      askPrompt: askPrompt,
      askCitedEntryIds: askCitedEntryIds,
      compact: compact,
    );
  }
}
