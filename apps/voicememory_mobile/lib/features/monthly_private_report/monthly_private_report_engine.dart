import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../private_report/private_report_builder.dart';
import '../private_report/private_report_copy.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../quiet_signal/quiet_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'monthly_private_report_copy.dart';
import 'monthly_private_report_model.dart';

/// Builds monthly private report preview from existing proof engines only.
abstract final class MonthlyPrivateReportEngine {
  MonthlyPrivateReportEngine._();

  static MonthlyPrivateReportDisplay buildDisplay() {
    return MonthlyPrivateReportDisplay(
      title: MonthlyPrivateReportCopy.cardTitle,
      body: MonthlyPrivateReportCopy.cardBody,
      proReason: MonthlyPrivateReportCopy.proReason,
      chatDifferentiation: MonthlyPrivateReportCopy.chatDifferentiation,
      cta: MonthlyPrivateReportCopy.cta,
      secondary: MonthlyPrivateReportCopy.secondary,
      sheetTitle: MonthlyPrivateReportCopy.sheetTitle,
      sheetIntro: MonthlyPrivateReportCopy.sheetIntro,
      proValueLine: MonthlyPrivateReportCopy.proValueLine,
      sheetSeeProCta: MonthlyPrivateReportCopy.sheetSeeProCta,
    );
  }

  static MonthlyPrivateReportPreview? build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = true,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    final report = PrivateReportBuilder.build(
      entries: entries,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
    );
    if (report == null) return null;

    final sections = <MonthlyPrivateReportSection>[];

    MonthlyPrivateReportSection? mapSection({
      required String reportHeading,
      required String previewHeading,
      required MonthlyPrivateReportSectionType type,
    }) {
      for (final section in report.sections) {
        if (section.heading != reportHeading || !section.hasEvidence) continue;
        final lines = section.lines
            .where(
              (line) =>
                  line.trim().isNotEmpty &&
                  line.trim() != PrivateReportCopy.sectionFallback,
            )
            .map((line) => '${MonthlyPrivateReportCopy.formingPrefix} $line')
            .toList();
        final bullets = section.bullets
            .where((bullet) => bullet.trim().isNotEmpty)
            .toList();
        if (lines.isEmpty && bullets.isEmpty) return null;
        return MonthlyPrivateReportSection(
          type: type,
          heading: previewHeading,
          lines: lines,
          bullets: bullets,
        );
      }
      return null;
    }

    void addIfPresent(MonthlyPrivateReportSection? section) {
      if (section != null && section.hasContent) sections.add(section);
    }

    addIfPresent(
      mapSection(
        reportHeading: PrivateReportCopy.whatRepeatedHeading,
        previewHeading: MonthlyPrivateReportCopy.whatKeptReturningHeading,
        type: MonthlyPrivateReportSectionType.whatKeptReturning,
      ),
    );
    addIfPresent(
      mapSection(
        reportHeading: PrivateReportCopy.whatChangedHeading,
        previewHeading: MonthlyPrivateReportCopy.whatChangedHeading,
        type: MonthlyPrivateReportSectionType.whatChanged,
      ),
    );
    addIfPresent(
      mapSection(
        reportHeading: PrivateReportCopy.whatHelpedHeading,
        previewHeading: MonthlyPrivateReportCopy.whatHelpedHeading,
        type: MonthlyPrivateReportSectionType.whatHelped,
      ),
    );

    final quiet = QuietSignalEngine.build(entries: entries);
    final quietLine = quiet?.privateReportLine?.trim() ?? quiet?.body.trim();
    if (quietLine != null && quietLine.isNotEmpty) {
      sections.add(
        MonthlyPrivateReportSection(
          type: MonthlyPrivateReportSectionType.whatWentQuiet,
          heading: MonthlyPrivateReportCopy.whatWentQuietHeading,
          lines: ['${MonthlyPrivateReportCopy.formingPrefix} $quietLine'],
        ),
      );
    }

    addIfPresent(
      mapSection(
        reportHeading: PrivateReportCopy.evidenceHeading,
        previewHeading: MonthlyPrivateReportCopy.evidenceHeading,
        type: MonthlyPrivateReportSectionType.evidence,
      ),
    );

    if (sections.isEmpty) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    return MonthlyPrivateReportPreview(
      sections: sections,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasChangeSignal: sections.any(
        (section) => section.type == MonthlyPrivateReportSectionType.whatChanged,
      ),
      hasHelpedSignal: sections.any(
        (section) => section.type == MonthlyPrivateReportSectionType.whatHelped,
      ),
      hasQuietSignal: sections.any(
        (section) => section.type == MonthlyPrivateReportSectionType.whatWentQuiet,
      ),
    );
  }

  static MonthlyPrivateReportContext buildContext({
    required MonthlyPrivateReportSurface surface,
    required int entryCount,
    required bool isPro,
    required bool dismissed,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    MonthlyPrivateReportPreview? preview,
    bool isZeroEntryState = false,
    bool isFirstRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool viewingConfirmedRepeatOrTimeline = true,
    bool isRecording = false,
    bool isPostSave = false,
    bool proLockMomentVisible = false,
    bool proEvidenceValueVisible = false,
  }) {
    final resolvedPreview = preview ??
        build(
          entries: entries,
          returnChecks: returnChecks,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
          isRecording: isRecording,
          isPostSave: isPostSave,
        );
    return MonthlyPrivateReportContext(
      surface: surface,
      entryCount: entryCount,
      isPro: isPro,
      dismissed: dismissed,
      hasConfirmedRepeat:
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
      preview: resolvedPreview,
      isZeroEntryState: isZeroEntryState,
      isFirstRecordingState: isFirstRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems:
          ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      ),
      proLockMomentVisible: proLockMomentVisible,
      proEvidenceValueVisible: proEvidenceValueVisible,
    );
  }

  static bool shouldShowCard(MonthlyPrivateReportContext context) {
    if (_isBlocked(context)) return false;
    final preview = context.preview;
    if (preview == null || !preview.hasSufficientEvidence) return false;
    if (context.entryCount <= 1 && !context.hasConfirmedRepeat) return false;
    if (!context.hasConfirmedRepeat &&
        !preview.hasChangeSignal &&
        !preview.hasHelpedSignal &&
        !preview.hasQuietSignal) {
      return false;
    }
    return true;
  }

  static bool _isBlocked(MonthlyPrivateReportContext context) {
    if (context.isPro) return true;
    if (context.dismissed) return true;
    if (context.proLockMomentVisible) return true;
    if (context.proEvidenceValueVisible) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isFirstRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    return false;
  }
}
