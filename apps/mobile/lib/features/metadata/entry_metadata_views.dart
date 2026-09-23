import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Transcribed note with a compact surroundings badge.
class EntryDetailView extends StatelessWidget {
  const EntryDetailView({
    required this.transcript,
    super.key,
    this.metadata,
  });

  final String transcript;
  final AmbientMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final badge = metadata?.badgeText;
    final note = transcript.trim();
    if (badge == null && note.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[
          AmbientMetadataBadge(label: badge),
          if (note.isNotEmpty) const SizedBox(height: AppTokens.spacing3),
        ],
        if (note.isNotEmpty)
          Text(
            transcript,
            key: const Key('entry_detail_recorded_body'),
            style: AppTokens.writing(),
          ),
      ],
    );
  }
}

/// Card row that keeps the surroundings badge with the note.
class EntryCardTile extends StatelessWidget {
  const EntryCardTile({
    required this.transcript,
    super.key,
    this.metadata,
    this.showTranscript = true,
  });

  final String transcript;
  final AmbientMetadata? metadata;
  final bool showTranscript;

  @override
  Widget build(BuildContext context) {
    final badge = metadata?.badgeText;
    if (badge == null && !showTranscript) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[
          const SizedBox(height: AppTokens.spacing3),
          AmbientMetadataBadge(label: badge),
        ],
        if (showTranscript) ...[
          if (badge != null) const SizedBox(height: AppTokens.spacing2),
          Text(
            transcript,
            key: const Key('entry_card_transcript'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.writing(),
          ),
        ],
      ],
    );
  }
}

class AmbientMetadataBadge extends StatelessWidget {
  const AmbientMetadataBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('ambient_metadata_badge'),
      decoration: BoxDecoration(
        color: AppTokens.primary50,
        borderRadius: BorderRadius.circular(AppTokens.spacing4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacing3,
          vertical: AppTokens.spacing2,
        ),
        child: Text(
          label,
          key: const Key('ambient_metadata_badge_label'),
          style: AppTokens.caption(color: AppTokens.primary700),
        ),
      ),
    );
  }
}
