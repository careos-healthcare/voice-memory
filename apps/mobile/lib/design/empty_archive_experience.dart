import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/belief_empty_state.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/record/start_here_loader.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Canonical copy for first-time / low-data surfaces.
abstract class EmptyArchiveCopy {
  EmptyArchiveCopy._();

  static String get intentionalEmptyTitle =>
      englishLocalizations.patternsEmptyPageTitle;
  static String get intentionalEmptyOpening =>
      englishLocalizations.patternsEarlyStateBody;

  static String get recordThoughtCta => englishLocalizations.patternsEmptyCta;
  static const String typeInsteadCta = VisibleArchiveProofCopy.typeInsteadCta;

  static const String firstRecordingTitle =
      'Your archive starts with one real moment.';
  static String get firstRecordingBody => intentionalEmptyOpening;

  static const String progressEmptyTitle = ConsumerUiCopy.progressEmptyTitle;
  static const String progressEmptyBody = ConsumerUiCopy.progressEmptyBody;

  static const String needMoreEvidenceTitle =
      ConsumerUiCopy.needMoreReflectionsTitle;
  static const String needMoreEvidenceBody =
      ConsumerUiCopy.needMoreReflectionsBody;

  static const String searchIdleTitle = ConsumerUiCopy.searchIdleTitle;
  static const String searchIdleBody = ConsumerUiCopy.searchIdleBody;

  static const String intentionalEmptyLongTermRecord =
      'Patterns emerge when you record ordinary moments over time.';
  static const intentionalEmptyPatternsOverTime =
      'Your archive shows what keeps repeating and what changes.';
  static const String intentionalEmptyFutureIntro =
      'As you add more moments, your archive can show:';
  static const List<String> intentionalEmptyFutureQuotes = [
    'What keeps repeating',
    'What changed',
    'What may have helped',
  ];
  static const String intentionalEmptyClosing = 'Start with one short moment.';
}

/// Max width for intentional empty copy — readable on tablets.
const double kIntentionalEmptyArchiveMaxWidth = 400;

/// Headline + one sentence + optional single CTA — no metrics or analytics tone.
class EmptyArchivePanel extends StatelessWidget {
  const EmptyArchivePanel({
    required this.title, required this.body, super.key,
    this.ctaLabel,
    this.onCta,
    this.showCaptureActions = false,
    this.onRecord,
    this.centered = false,
  });

  factory EmptyArchivePanel.firstRecording({
    Key? key,
    VoidCallback? onRecord,
    bool centered = false,
  }) {
    return EmptyArchivePanel(
      key: key,
      title: EmptyArchiveCopy.firstRecordingTitle,
      body: EmptyArchiveCopy.firstRecordingBody,
      showCaptureActions: true,
      onRecord: onRecord,
      centered: centered,
    );
  }

  factory EmptyArchivePanel.archiveEmpty({
    Key? key,
    VoidCallback? onRecord,
    bool centered = false,
  }) {
    return EmptyArchivePanel(
      key: key,
      title: EmptyArchiveCopy.intentionalEmptyTitle,
      body: EmptyArchiveCopy.intentionalEmptyOpening,
      showCaptureActions: true,
      onRecord: onRecord,
      centered: centered,
    );
  }

  factory EmptyArchivePanel.needMoreEvidence({
    Key? key,
    bool centered = false,
  }) {
    return EmptyArchivePanel(
      key: key,
      title: EmptyArchiveCopy.needMoreEvidenceTitle,
      body: EmptyArchiveCopy.needMoreEvidenceBody,
      centered: centered,
    );
  }

  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool showCaptureActions;
  final VoidCallback? onRecord;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.foreground,
      height: 1.3,
    );
    const bodyStyle = TextStyle(
      color: AppTheme.muted,
      height: 1.45,
      fontSize: 15,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: titleStyle,
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: bodyStyle,
        ),
        if (showCaptureActions) ...[
          const SizedBox(height: 20),
          const StartHereLoader(surface: 'empty_archive_panel'),
          const SizedBox(height: 16),
          CaptureEntryActions(
            onRecord: onRecord ?? () => goToFirstRecording(context),
          ),
        ] else if (ctaLabel != null && onCta != null) ...[
          const SizedBox(height: 20),
          FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
        ],
      ],
    );

    if (!centered) return content;

    return Center(
      child: Padding(padding: const EdgeInsets.all(32), child: content),
    );
  }
}

/// True when Discover/Archive should show intentional empty UI (no spinner).
bool isIntentionalEmptyArchive(List<JournalEntry> entries) {
  if (entries.isEmpty) return true;
  return archiveEvidenceReflectionCount(entries) == 0;
}

/// Synchronous journal peek — avoids a loading flash on first Discover paint.
List<JournalEntry> peekJournalEntriesSync(JournalStore store) {
  try {
    return store.loadAllSync();
  } catch (_, stackTrace) {
    return const [];
  }
}

/// Max width for example insight block — readable on phones and tablets.
const double kIntentionalEmptyInsightMaxWidth = 360;

/// Legacy wrapper — delegates to [BeliefEmptyState].
class IntentionalEmptyArchiveContent extends StatelessWidget {
  const IntentionalEmptyArchiveContent({
    super.key,
    this.onRecord,
    this.centered = true,
  });

  final VoidCallback? onRecord;
  final bool centered;

  static String get semanticsLabel =>
      '${EmptyArchiveCopy.intentionalEmptyTitle}. '
      '${EmptyArchiveCopy.intentionalEmptyOpening}';

  @override
  Widget build(BuildContext context) {
    return BeliefEmptyState(centered: centered);
  }
}

/// Legacy wrapper — delegates to [BeliefEmptyState].
class IntentionalEmptyArchiveView extends StatelessWidget {
  const IntentionalEmptyArchiveView({
    super.key,
    this.onRecord,
    this.centered = true,
    this.fillViewport = true,
  });

  final VoidCallback? onRecord;
  final bool centered;
  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    return BeliefEmptyState(centered: centered, fillViewport: fillViewport);
  }
}

/// Routes to Record tab — default CTA for first-recording empty states.
void goToFirstRecording(BuildContext context) => context.go('/record');