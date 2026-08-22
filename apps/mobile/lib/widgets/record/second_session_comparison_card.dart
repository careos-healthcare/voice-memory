import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Second-recording comparison card — conservative, evidence-focused.
class SecondSessionComparisonCard extends StatelessWidget {
  const SecondSessionComparisonCard({
    required this.comparison, required this.onGoDeeper, required this.onRecordNextEvidence, required this.onNotTheSame, super.key,
  });

  final SecondSessionComparison comparison;
  final VoidCallback onGoDeeper;
  final VoidCallback onRecordNextEvidence;
  final VoidCallback onNotTheSame;

  @override
  Widget build(BuildContext context) {
    if (!comparison.hasEnoughData) {
      return _InsufficientCard(onRecordNext: onRecordNextEvidence);
    }

    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            comparison.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            comparison.body,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (comparison.previousSignalLabel != null &&
              comparison.latestSignalLabel != null &&
              comparison.possibleRepeat) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.secondSessionCompareTemplate
                  .replaceAll('{previous}', comparison.previousSignalLabel!)
                  .replaceAll('{latest}', comparison.latestSignalLabel!),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.secondSessionBetterEvidence,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          if (comparison.whatRepeated != null) ...[
            SizedBox(height: gap),
            _Section(
              label: ConsumerUiCopy.secondSessionWhatRepeated,
              body: comparison.whatRepeated!,
            ),
          ],
          if (comparison.whatChanged != null) ...[
            SizedBox(height: gap),
            _Section(
              label: ConsumerUiCopy.secondSessionWhatChanged,
              body: comparison.whatChanged!,
            ),
          ],
          if (comparison.whatToTestNext != null) ...[
            SizedBox(height: gap),
            _Section(
              label: ConsumerUiCopy.secondSessionWhatToTestNext,
              body: comparison.whatToTestNext!,
            ),
          ],
          SizedBox(height: gap),
          FilledButton(
            onPressed: onGoDeeper,
            child: const Text(ConsumerUiCopy.postSaveInsightGoDeeper),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onRecordNextEvidence,
            child: const Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onNotTheSame,
            child: const Text(ConsumerUiCopy.secondSessionNotTheSame),
          ),
        ],
      ),
    );
  }
}

class _InsufficientCard extends StatelessWidget {
  const _InsufficientCard({required this.onRecordNext});

  final VoidCallback onRecordNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.secondSessionNeedMoreMoments,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: ArchiveResponsiveLayout.gap(context)),
          FilledButton(
            onPressed: onRecordNext,
            child: const Text(ConsumerUiCopy.postSaveRecordAnother),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(body, style: ArchiveMobileTypography.explanationBody(context)),
      ],
    );
  }
}