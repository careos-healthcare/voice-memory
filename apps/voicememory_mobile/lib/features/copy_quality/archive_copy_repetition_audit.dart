import 'package:flutter/foundation.dart';

class ArchiveCopyRepetitionAuditResult {
  const ArchiveCopyRepetitionAuditResult({
    required this.approved,
    required this.repeatedTerms,
    required this.genericPhrases,
    required this.suggestedFixes,
  });

  final bool approved;
  final List<String> repeatedTerms;
  final List<String> genericPhrases;
  final List<String> suggestedFixes;
}

abstract class ArchiveCopyRepetitionAudit {
  ArchiveCopyRepetitionAudit._();

  static const repeatedWatchTerms = <String>[
    'checking',
    'relief',
    'pattern',
    'loop',
    'something',
    'moment',
    'may',
    'could',
    'useful check',
    'comes back',
  ];

  static const genericPhrases = <String>[
    'something is happening',
    'a possible thread is forming',
    'this may be about',
    'notice what happens',
    'record another moment',
    'your map is getting sharper',
    'your map gets sharper',
  ];

  static const _standaloneWhatChanged = 'what changed';

  static ArchiveCopyRepetitionAuditResult checkScreen({
    required String screenName,
    required List<String> visiblePhrases,
  }) {
    final combined = visiblePhrases
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toList();
    final screenBlob = combined.join(' ');

    final repeatedTerms = <String>[];
    for (final term in repeatedWatchTerms) {
      final count = _countTerm(screenBlob, term);
      if (count >= 3) {
        repeatedTerms.add(term);
      }
    }

    final genericHits = <String>[];
    for (final phrase in genericPhrases) {
      if (screenBlob.contains(phrase)) {
        genericHits.add(phrase);
      }
    }

    final whatChangedCount = _countTerm(screenBlob, _standaloneWhatChanged);
    if (whatChangedCount >= 2 &&
        !_hasEvidenceContext(screenBlob, _standaloneWhatChanged)) {
      genericHits.add(_standaloneWhatChanged);
    }

    final suggestedFixes = _suggestedFixes(
      repeatedTerms: repeatedTerms,
      genericPhrases: genericHits,
    );

    final approved = repeatedTerms.isEmpty && genericHits.isEmpty;
    _log(
      screenName: screenName,
      approved: approved,
      repeatedTerms: repeatedTerms,
      genericPhrases: genericHits,
    );

    return ArchiveCopyRepetitionAuditResult(
      approved: approved,
      repeatedTerms: repeatedTerms,
      genericPhrases: genericHits,
      suggestedFixes: suggestedFixes,
    );
  }

  static int _countTerm(String blob, String term) {
    if (term.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while (true) {
      index = blob.indexOf(term, index);
      if (index < 0) break;
      count++;
      index += term.length;
    }
    return count;
  }

  static bool _hasEvidenceContext(String blob, String term) {
    const evidenceMarkers = [
      'since your earlier recording',
      'your latest recording added',
      'since last time',
      'across your recordings',
      'what your latest recording',
    ];
    for (final marker in evidenceMarkers) {
      if (blob.contains(marker)) return true;
    }
    return blob.contains('$term since') || blob.contains('$term in your');
  }

  static List<String> _suggestedFixes({
    required List<String> repeatedTerms,
    required List<String> genericPhrases,
  }) {
    final fixes = <String>[];
    for (final term in repeatedTerms) {
      fixes.add('Reduce repeated use of "$term" on this screen.');
    }
    for (final phrase in genericPhrases) {
      fixes.add(switch (phrase) {
        'record another moment' =>
          'Try "Record the next time this shows up."',
        'your map is getting sharper' || 'your map gets sharper' =>
          'Try "ArchiveMe has one more piece of evidence."',
        'this may be about' => 'Try "Your words point to…" or "The strongest clue is…"',
        'what changed' =>
          'Try "What changed since your earlier recording."',
        _ => 'Replace generic phrase "$phrase" with evidence-based wording.',
      });
    }
    return fixes;
  }

  static void _log({
    required String screenName,
    required bool approved,
    required List<String> repeatedTerms,
    required List<String> genericPhrases,
  }) {
    final repeated = repeatedTerms.isEmpty ? 'none' : repeatedTerms.join(',');
    final generic = genericPhrases.isEmpty ? 'none' : genericPhrases.join(',');
    debugPrint(
      'ARCHIVEME_COPY_REPETITION_AUDIT screen=$screenName '
      'approved=$approved repeated=$repeated generic=$generic',
    );
  }
}
