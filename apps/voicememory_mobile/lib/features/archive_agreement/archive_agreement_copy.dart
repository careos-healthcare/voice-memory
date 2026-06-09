import 'archive_agreement_models.dart';

/// User-facing archive agreement strings.
abstract final class ArchiveAgreementCopy {
  ArchiveAgreementCopy._();

  static const String sectionTitle = 'Your take on this theory';

  static const String prompt =
      'Does this match how you see yourself right now?';

  static const String metadataNote =
      'Saved on this device only. Your responses are metadata — they do not change how the archive is built.';

  static const String agreeLabel = 'Agree';
  static const String unsureLabel = 'Unsure';
  static const String disagreeLabel = 'Disagree';

  static const String historyTitle = 'Agreement history';
  static const String historyEmpty =
      'Your agreement responses will appear here after you respond.';

  static String responseLabel(ArchiveTheoryAgreementResponse response) =>
      switch (response) {
        ArchiveTheoryAgreementResponse.agree => agreeLabel,
        ArchiveTheoryAgreementResponse.unsure => unsureLabel,
        ArchiveTheoryAgreementResponse.disagree => disagreeLabel,
      };

  static String truncateTheory(String text, {int max = 72}) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}
