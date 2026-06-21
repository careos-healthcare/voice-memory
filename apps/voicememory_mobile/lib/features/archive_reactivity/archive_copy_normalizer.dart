/// Canonical archive display-copy normalizer shared by grammar and product gates.
abstract class ArchiveCopyNormalizer {
  ArchiveCopyNormalizer._();

  static const residualMalformedTokens = [
    'checkingfor',
    'youreally',
    'youkeep',
    'mayalso',
    'archivemeis',
    'archivemeshould',
    'archivemewill',
    'archivemenoticed',
    'onemore',
    'maysit',
    'nexttime',
    'thisentry',
    'thisone',
    'thistomorrow',
    'ifit',
    'noticewhat',
    'watchthis',
    'watchthe',
    'seewhether',
    'returnnaturally',
    'pressurearrives',
    'time,notice',
    'time,watch',
    'reliefand',
    'andrisk',
    'anothersign',
    'thoughtturns',
    'istrying',
    'reliefconnector',
    'alternativeconnector',
    'checkwas',
    'trustit',
    'existingthread',
    'aneed',
    'isbasing',
    'needstowork',
    'towork',
    'separateuseful',
    'usefulcheck',
    'reliefattempt',
    'mapready',
  ];

  static const _archiveMeGlueWords = [
    'is',
    'should',
    'will',
    'noticed',
    'may',
  ];

  static const _youGlueWords = [
    'really',
    'keep',
    'said',
    'need',
    'may',
    'can',
    'could',
  ];

  static const _mayGlueWords = [
    'also',
    'be',
    'not',
  ];

  static const _thisGlueWords = [
    'tomorrow',
    'entry',
    'one',
  ];

  static const _ifGlueWords = [
    'it',
  ];

  static const _noticeGlueWords = [
    'what',
    'whether',
  ];

  static const _watchGlueWords = [
    'this',
    'the',
  ];

  static const _seeGlueWords = [
    'whether',
    'if',
  ];

  static const _returnGlueWords = [
    'naturally',
  ];

  static const _pressureGlueWords = [
    'arrives',
  ];

  static const _anotherGlueWords = [
    'sign',
    'check',
  ];

  static const _thoughtGlueWords = [
    'turns',
  ];

  static const _isGlueWords = [
    'trying',
    'basing',
  ];

  static const _checkGlueWords = [
    'was',
  ];

  static const _trustGlueWords = [
    'it',
  ];

  static const _existingGlueWords = [
    'thread',
  ];

  static const _reliefConnectorGlueWords = [
    'connector',
  ];

  static const _alternativeConnectorGlueWords = [
    'connector',
  ];

  static String normalize(String input) {
    var normalized = input.trim();
    if (normalized.isEmpty) return '';

    const literalReplacements = <String, String>{
      'ArchiveMeshould': 'ArchiveMe should',
      'ArchiveMeis': 'ArchiveMe is',
      'ArchiveMewill': 'ArchiveMe will',
      'ArchiveMenoticed': 'ArchiveMe noticed',
      'onemore': 'one more',
      'maysit': 'may sit',
      'mayalso': 'may also',
      'youreally': 'you really',
      'youkeep': 'you keep',
      'checkingfor': 'checking for',
      'reliefand': 'relief and',
      'andrisk': 'and risk',
      'nexttime': 'next time',
      'thisentry': 'this entry',
      'thisone': 'this one',
      'thistomorrow': 'this tomorrow',
      'ifit': 'if it',
      'noticewhat': 'notice what',
      'watchthe': 'watch the',
      'watchthis': 'watch this',
      'seewhether': 'see whether',
      'returnnaturally': 'return naturally',
      'pressurearrives': 'pressure arrives',
      'maybe driving': 'may be driving',
      'anothersign': 'another sign',
      'thoughtturns': 'thought turns',
      'istrying': 'is trying',
      'reliefconnector': 'relief connector',
      'alternativeconnector': 'alternative connector',
      'checkwas': 'check was',
      'trustit': 'trust it',
      'existingthread': 'existing thread',
      'aneed': 'a need',
      'isbasing': 'is basing',
      'needstowork': 'needs to work',
      'needs towork': 'needs to work',
      'towork': 'to work',
      'separateuseful': 'separate useful',
      'usefulcheck': 'useful check',
      'reliefattempt': 'relief attempt',
      'mapready': 'map ready',
    };

    for (final entry in literalReplacements.entries) {
      normalized = normalized.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }

    normalized = normalized.replaceAllMapped(
      RegExp(r'needs\s+towork', caseSensitive: false),
      (_) => 'needs to work',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'to=(\w+)connector=', caseSensitive: false),
      (match) => 'to=${match.group(1)} connector=',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r',([A-Za-z])'),
      (match) => ', ${match.group(1)}',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'\.([A-Za-z])'),
      (match) => '. ${match.group(1)}',
    );

    normalized = normalized.replaceAllMapped(
      RegExp(r'ArchiveMe([a-z][a-z]+)', caseSensitive: false),
      (match) => 'ArchiveMe ${match.group(1)!}',
    );

    normalized = _applyGlueWords(normalized, 'you', _youGlueWords);
    normalized = _applyGlueWords(normalized, 'may', _mayGlueWords);
    normalized = _applyGlueWords(normalized, 'this', _thisGlueWords);
    normalized = _applyGlueWords(normalized, 'if', _ifGlueWords);
    normalized = _applyGlueWords(normalized, 'notice', _noticeGlueWords);
    normalized = _applyGlueWords(normalized, 'watch', _watchGlueWords);
    normalized = _applyGlueWords(normalized, 'see', _seeGlueWords);
    normalized = _applyGlueWords(normalized, 'return', _returnGlueWords);
    normalized = _applyGlueWords(normalized, 'pressure', _pressureGlueWords);
    normalized = _applyGlueWords(normalized, 'another', _anotherGlueWords);
    normalized = _applyGlueWords(normalized, 'thought', _thoughtGlueWords);
    normalized = _applyGlueWords(normalized, 'is', _isGlueWords);
    normalized = _applyGlueWords(normalized, 'check', _checkGlueWords);
    normalized = _applyGlueWords(normalized, 'trust', _trustGlueWords);
    normalized = _applyGlueWords(normalized, 'existing', _existingGlueWords);
    normalized = _applyGlueWords(normalized, 'relief', _reliefConnectorGlueWords);
    normalized = _applyGlueWords(
      normalized,
      'alternative',
      _alternativeConnectorGlueWords,
    );
    normalized = normalized.replaceAll(
      RegExp(r'\ba([Nn])eed\b'),
      'a need',
    );

    for (final word in _archiveMeGlueWords) {
      normalized = normalized.replaceAll(
        RegExp('archiveme${RegExp.escape(word)}', caseSensitive: false),
        'ArchiveMe $word',
      );
    }

    normalized = normalized.replaceAll(RegExp(r'\s{2,}'), ' ');
    return normalized.trim();
  }

  static String _applyGlueWords(
    String text,
    String prefix,
    List<String> words,
  ) {
    var normalized = text;
    for (final word in words) {
      normalized = normalized.replaceAll(
        RegExp('${RegExp.escape(prefix)}${RegExp.escape(word)}', caseSensitive: false),
        '$prefix $word',
      );
    }
    return normalized;
  }

  static bool hasResidualMalformedText(String normalized) {
    if (normalized.trim().isEmpty) return false;

    final lower = normalized.toLowerCase();
    for (final token in residualMalformedTokens) {
      if (lower.contains(token)) return true;
    }

    if (RegExp(r',[^\s]').hasMatch(normalized)) return true;

    final withoutArchiveMe = normalized.replaceAll(
      RegExp(r'ArchiveMe', caseSensitive: false),
      '',
    );
    if (RegExp(r'[a-z][A-Z]').hasMatch(withoutArchiveMe)) return true;

    return false;
  }
}
