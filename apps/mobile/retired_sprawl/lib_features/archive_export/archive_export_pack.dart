import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_export/archive_export_pack_copy.dart';
import 'package:archiveme_mobile/features/evidence_contract/derived_claim_mapper.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';

/// One recent moment line in the export pack preview.
class ArchiveExportPackMoment {
  const ArchiveExportPackMoment({
    required this.createdAt,
    required this.preview,
    this.contextTagLabel,
    this.usableEvidence = true,
  });

  final DateTime createdAt;
  final String preview;
  final String? contextTagLabel;
  final bool usableEvidence;
}

/// Local Archive Export Pack — explicit, user-initiated, device-only.
class ArchiveExportPack {
  const ArchiveExportPack({
    required this.isEmpty,
    required this.exportedAt,
    required this.savedMomentCount,
    required this.usableEvidenceCount,
    required this.plainText,
    this.currentBeliefLine,
    this.evidenceMapSummary = const [],
    this.weeklyReviewSummary,
    this.recentMoments = const [],
  });

  final bool isEmpty;
  final DateTime exportedAt;
  final int savedMomentCount;
  final int usableEvidenceCount;
  final String? currentBeliefLine;
  final List<String> evidenceMapSummary;
  final String? weeklyReviewSummary;
  final List<ArchiveExportPackMoment> recentMoments;
  final String plainText;

  Map<String, dynamic> toJson() => {
    'app': 'ArchiveMe',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'savedMomentCount': savedMomentCount,
    'usableEvidenceCount': usableEvidenceCount,
    if (currentBeliefLine != null) 'currentBeliefLine': currentBeliefLine,
    if (evidenceMapSummary.isNotEmpty) 'evidenceMapSummary': evidenceMapSummary,
    if (weeklyReviewSummary != null) 'weeklyReviewSummary': weeklyReviewSummary,
    'recentMoments': recentMoments
        .map(
          (moment) => {
            'date': moment.createdAt.toUtc().toIso8601String().substring(0, 10),
            'preview': moment.preview,
            if (moment.contextTagLabel != null)
              'contextTag': moment.contextTagLabel,
            'usableEvidence': moment.usableEvidence,
          },
        )
        .toList(),
    'privacyNotes': [
      ArchiveExportPackCopy.privacyNoteDevice,
      ArchiveExportPackCopy.privacyNoteReview,
    ],
  };
}

/// Builds a deterministic local export pack from journal entries.
abstract final class ArchiveExportPackEngine {
  ArchiveExportPackEngine._();

  static const _maxRecentMoments = 5;
  static const _previewChars = 120;

  static ArchiveExportPack build({
    required List<JournalEntry> entries,
    DateTime? exportedAt,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final at = (exportedAt ?? DateTime.now()).toUtc();
    final saved = List<JournalEntry>.from(realEntries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (saved.isEmpty) {
      return ArchiveExportPack(
        isEmpty: true,
        exportedAt: at,
        savedMomentCount: 0,
        usableEvidenceCount: 0,
        plainText: '',
      );
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(realEntries);
    final eligibleIds = eligible.map((entry) => entry.id).toSet();
    final archiveHome = ArchiveHomeSummaryEngine.build(entries: realEntries);
    final evidenceMap = ArchiveEvidenceMapEngine.build(entries: realEntries);
    final weeklyReview = WeeklyArchiveReviewEngine.build(entries: realEntries);

    final evidenceMapSummary = evidenceMap.rows
        .map(
          (row) => ArchiveExportPackCopy.evidenceMapRow(row.label, row.count),
        )
        .toList();

    final weeklyReviewSummary = weeklyReview.hasEnoughEvidence
        ? _weeklyReviewSummary(weeklyReview)
        : null;

    final currentBeliefLine = _currentBeliefLine(archiveHome.currentBeliefLine);

    final recentMoments = saved.take(_maxRecentMoments).map((entry) {
      final preview = _previewForEntry(entry);
      return ArchiveExportPackMoment(
        createdAt: entry.createdAt,
        preview: preview,
        contextTagLabel: CaptureContextTags.labelForEntry(entry),
        usableEvidence: eligibleIds.contains(entry.id),
      );
    }).toList();

    final plainText = _plainText(
      exportedAt: at,
      savedMomentCount: saved.length,
      usableEvidenceCount: eligible.length,
      currentBeliefLine: currentBeliefLine,
      evidenceMapSummary: evidenceMapSummary,
      weeklyReviewSummary: weeklyReviewSummary,
      recentMoments: recentMoments,
      derivedClaims: _derivedClaimsForExport(saved),
    );

    return ArchiveExportPack(
      isEmpty: false,
      exportedAt: at,
      savedMomentCount: saved.length,
      usableEvidenceCount: eligible.length,
      currentBeliefLine: currentBeliefLine,
      evidenceMapSummary: evidenceMapSummary,
      weeklyReviewSummary: weeklyReviewSummary,
      recentMoments: recentMoments,
      plainText: plainText,
    );
  }

  static String? _currentBeliefLine(String? line) {
    final trimmed = line?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _weeklyReviewSummary(WeeklyArchiveReview review) {
    final parts = <String>[
      if (review.subtitle != null && review.subtitle!.trim().isNotEmpty)
        review.subtitle!.trim(),
      if (review.strongestThreadLine != null &&
          review.strongestThreadLine!.trim().isNotEmpty)
        review.strongestThreadLine!.trim(),
      if (review.whatChangedLine != null &&
          review.whatChangedLine!.trim().isNotEmpty)
        review.whatChangedLine!.trim(),
    ];
    if (parts.isEmpty) return review.title;
    return parts.join(' ');
  }

  static String _previewForEntry(JournalEntry entry) {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
      return ArchiveExportPackCopy.previewUnavailable;
    }
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.trim().isEmpty) {
      return ArchiveExportPackCopy.previewUnavailable;
    }
    return UserContentSafety.safeSnippet(
      resolution.text,
      maxChars: _previewChars,
    );
  }

  static String _plainText({
    required DateTime exportedAt,
    required int savedMomentCount,
    required int usableEvidenceCount,
    required String? currentBeliefLine,
    required List<String> evidenceMapSummary,
    required String? weeklyReviewSummary,
    required List<ArchiveExportPackMoment> recentMoments,
    required List<Map<String, Object>> derivedClaims,
  }) {
    final buffer = StringBuffer()
      ..writeln(ArchiveExportPackCopy.headerTitle)
      ..writeln()
      ..writeln(
        '${ArchiveExportPackCopy.exportDateLabel}: ${_formatDate(exportedAt)}',
      )
      ..writeln('${ArchiveExportPackCopy.savedMomentsLabel}: $savedMomentCount')
      ..writeln(
        '${ArchiveExportPackCopy.usableEvidenceLabel}: $usableEvidenceCount',
      );

    if (currentBeliefLine != null) {
      buffer
        ..writeln()
        ..writeln('${ArchiveExportPackCopy.currentBeliefLabel}:')
        ..writeln(currentBeliefLine);
    }

    if (evidenceMapSummary.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${ArchiveExportPackCopy.evidenceMapLabel}:');
      for (final row in evidenceMapSummary) {
        buffer.writeln('- $row');
      }
    }

    if (weeklyReviewSummary != null) {
      buffer
        ..writeln()
        ..writeln('${ArchiveExportPackCopy.weeklyReviewLabel}:')
        ..writeln(weeklyReviewSummary);
    }

    if (recentMoments.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${ArchiveExportPackCopy.recentMomentsLabel}:');
      for (final moment in recentMoments) {
        buffer.writeln('- ${_formatDate(moment.createdAt)}');
        buffer.writeln('  ${moment.preview}');
        final tag = moment.contextTagLabel;
        if (tag != null && tag.isNotEmpty) {
          buffer.writeln('  Context: $tag');
        }
      }
    }

    if (derivedClaims.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${EvidenceEligibilityCopy.exportSuggestionLabel}:');
      for (final claim in derivedClaims) {
        buffer.writeln('- ${claim[EvidenceEligibilityCopy.exportSuggestionLabel]}');
      }
    }

    buffer
      ..writeln()
      ..writeln(ArchiveExportPackCopy.privacyNoteDevice)
      ..writeln(ArchiveExportPackCopy.privacyNoteReview)
      ..writeln()
      ..writeln(ArchiveExportPackCopy.reviewBeforeSharing);

    return buffer.toString().trimRight();
  }

  static List<Map<String, Object>> _derivedClaimsForExport(
    List<JournalEntry> entries,
  ) {
    final claims = <Map<String, Object>>[];
    for (final entry in entries) {
      final proof = entry.verifiedProof;
      if (proof == null) continue;
      for (final claim in proof.claims) {
        final derived = DerivedClaimMapper.fromVerifiedProofClaim(
          claim: claim,
          proof: proof,
          createdAt: entry.createdAt,
        );
        claims.add(DerivedClaimMapper.exportSectionFor(derived));
      }
    }
    return claims;
  }

  static String _formatDate(DateTime dateTime) =>
      dateTime.toUtc().toIso8601String().substring(0, 10);
}