import 'package:archiveme_mobile/design/warm_archive_copy.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Current archive belief — must render above all other archive content on mobile.
class ArchiveBeliefHeaderMobile extends StatelessWidget {
  const ArchiveBeliefHeaderMobile({
    required this.beliefText, super.key,
    this.confidenceLabel,
    this.statusLabel,
    this.reputationLabel,
  });

  final String beliefText;
  final String? confidenceLabel;
  final String? statusLabel;
  final String? reputationLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VoiceMemoryColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              WarmArchiveCopy.beliefConcept,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: VoiceMemoryColors.secondaryLavender,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              beliefText,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: VoiceMemoryColors.textPrimary,
              ),
            ),
            if (confidenceLabel != null ||
                statusLabel != null ||
                reputationLabel != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: VoiceMemoryColors.border),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (confidenceLabel != null)
                    _MetaChip(
                      label: WarmArchiveCopy.confidenceConcept,
                      value: confidenceLabel!,
                    ),
                  if (statusLabel != null)
                    _MetaChip(label: 'Status', value: statusLabel!),
                  if (reputationLabel != null)
                    _MetaChip(label: 'Reputation', value: reputationLabel!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: VoiceMemoryColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: VoiceMemoryColors.textPrimary,
          ),
        ),
      ],
    );
  }
}