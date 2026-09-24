import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_service.dart';
import 'package:archiveme_mobile/features/transcript/ui/transcript_detail_view.dart';
import 'package:flutter/material.dart';

/// Rewrite controls used under a transcript that is already on screen.
class GemmaSummaryPanel extends StatelessWidget {
  const GemmaSummaryPanel({
    required this.entryId,
    required this.transcript,
    super.key,
    this.service,
  });

  final String entryId;
  final String transcript;
  final GemmaSummaryService? service;

  @override
  Widget build(BuildContext context) {
    return TranscriptDetailView(
      entryId: entryId,
      transcript: transcript,
      service: service,
      showRawTranscript: false,
    );
  }
}
