import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'study_build_identity.dart';
import 'study_consent.dart';
import 'study_feedback.dart';
import 'study_metrics.dart';

/// Builds the one payload a participant ever sends back.
///
/// The builder takes counts, tokens and dates. It has no parameter that can
/// carry saved words, no import that reaches storage, and no import of the
/// file holding participant notes. On top of that structural limit, every leaf
/// of the finished payload is re-checked against [_tokenShape] before it is
/// returned: the shape has no space character, so a sentence cannot survive it
/// even if a future field tried to carry one.
abstract final class StudyExport {
  static const schemaVersion = 1;

  /// Keys and string values must both match. Digits, letters, `_ . : + -` only.
  static final _tokenShape = RegExp(r'^[A-Za-z0-9_.:+-]{1,64}$');

  static Map<String, Object?> build({
    required StudyConsentRecord consent,
    required StudyBuildIdentity build,
    required StudyMetrics metrics,
    required List<StudyFeedbackEntry> feedback,
    required int privateNoteCount,
    required DateTime generatedAt,
  }) {
    final payload = <String, Object?>{
      'study_schema_version': schemaVersion,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'build': build.toJson(),
      'consent': {
        'policy_version': consent.policyVersion,
        'state': consent.state.name,
        'granted_at': consent.grantedAt.toUtc().toIso8601String(),
        'revoked_at': consent.revokedAt?.toUtc().toIso8601String(),
        'acknowledged_statements': consent.acknowledgedStatementCount,
        'required_statements': StudyConsentPolicy.statements.length,
      },
      'participant': {
        'ref': participantRef(consent.archiveId),
        'code': consent.participantCode,
      },
      'metrics': {
        'first_signal_at': metrics.firstSignalAt?.toIso8601String(),
        'last_signal_at': metrics.lastSignalAt?.toIso8601String(),
        'active_day_count': metrics.activeDayCount,
        'signals': metrics.toSignalTotals(),
      },
      'feedback': {
        'entry_count': feedback.length,
        'private_note_count': privateNoteCount,
        'entries': [for (final entry in feedback) entry.toExportJson()],
      },
    };

    requireContentFree(payload);
    return payload;
  }

  static String encode({
    required StudyConsentRecord consent,
    required StudyBuildIdentity build,
    required StudyMetrics metrics,
    required List<StudyFeedbackEntry> feedback,
    required int privateNoteCount,
    required DateTime generatedAt,
  }) => const JsonEncoder.withIndent('  ').convert(
    StudyExport.build(
      consent: consent,
      build: build,
      metrics: metrics,
      feedback: feedback,
      privateNoteCount: privateNoteCount,
      generatedAt: generatedAt,
    ),
  );

  /// Stable, one-way handle for an archive.
  ///
  /// Lets a researcher tell two participants apart across submissions without
  /// the export carrying the archive id that names their content on disk.
  static String participantRef(String archiveId) => sha256
      .convert(utf8.encode('study_participant:$archiveId'))
      .toString()
      .substring(0, 16);

  /// Throws unless every key and leaf of [value] is content-free.
  static void requireContentFree(Object? value, [String path = 'root']) {
    if (value == null || value is int) return;

    if (value is String) {
      if (_tokenShape.hasMatch(value)) return;
      throw StateError('Free text in study export at "$path": rejected.');
    }

    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (!_tokenShape.hasMatch(key)) {
          throw StateError('Free-text key in study export at "$path.$key".');
        }
        requireContentFree(entry.value, '$path.$key');
      }
      return;
    }

    if (value is List) {
      for (var index = 0; index < value.length; index++) {
        requireContentFree(value[index], '$path[$index]');
      }
      return;
    }

    throw StateError(
      'Unsupported study export value of type ${value.runtimeType} at "$path".',
    );
  }
}
