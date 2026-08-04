import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _companionBannedPatterns = <String, String>{
  r'AI friend': 'AI friend',
  r'\bcompanion\b': 'companion',
  r'\btherapist\b': 'therapist',
  r'\btherapy\b': 'therapy',
  r'\bdiagnosis\b': 'diagnosis',
  r'mental health': 'mental health',
  r'\bwellness\b': 'wellness',
  r'\bhealing\b': 'healing',
  r'\btrauma\b': 'trauma',
  r'\bcoach\b': 'coach',
  r'\bcoaching\b': 'coaching',
  r'\baffirmation\b': 'affirmation',
  r'inner child': 'inner child',
  r'emotional support': 'emotional support',
  r'chat with': 'chat with',
  r'\bchatbot\b': 'chatbot',
  r'\bchat\b': 'chat',
  r'\bjournal\b': 'journal',
  r'\brosebud\b': 'Rosebud',
  r'AI journal': 'AI journal',
};

const _bannedPatterns = <String, String>{
  r'\bVoiceMemory\b': 'VoiceMemory',
  r'Cloud processing': 'Cloud processing',
  r'Cloud sync unavailable': 'Cloud sync unavailable',
  r'Cloud analysis pending': 'Cloud analysis pending',
  r'Never synced': 'Never synced',
  r'archive intelligence': 'archive intelligence',
  // The bare noun is deliberately allowed. "Your archive" is the reader-facing
  // word for their own saved moments and appears in required ownership copy
  // ("Export or delete your archive at any time"). The jargon compounds it was
  // introduced to catch — archive intelligence, analyst, blind spot — are
  // banned individually and remain banned.
  r'\bbeliefs?\b': 'belief/beliefs',
  r'\bintelligence\b': 'intelligence',
  r'\bdiscover(?:y|ies)?\b': 'discover/discovery',
  r'\btheory\b': 'theory',
  r'\banalyst\b': 'analyst',
  r'\bhistorian\b': 'historian',
  r'\bsynthesis\b': 'synthesis',
  r'\blifecycle\b': 'lifecycle',
  r'\bidentity profile\b': 'identity profile',
  r'\bblind spot\b': 'blind spot',
  r'\bcontradiction\b': 'contradiction',
  r'\bprediction\b': 'prediction',
};

const _legacyMicrocopyPatterns = <String, String>{
  r'\breflections?\b': 'reflection',
  r'\bjournal entr(?:y|ies)\b': 'journal entry',
  r'\bsessions?\b': 'session',
  r'\bdrift(?:ed|ing|s)?\b': 'drift',
};

/// Not consumer copy, so a literal match here proves nothing.
const _excludedFromBannedWordScan = <String>{
  // Stores the forbidden positioning phrases as its own pattern table. Scanning
  // it for those phrases only ever finds the guard itself. The copy in this
  // file is policed by product_positioning_copy_test.dart instead.
  'lib/product/auditable_change_positioning.dart',
};

/// Trial-only comprehension survey may use journal/chat labels.
const _companionCopyAllowedFiles = <String>{};

/// Consumer-visible copy sources (central + surfaces reachable from main tabs).
///
/// The V1 reduction deleted most of the surfaces this list once named. Rather
/// than shrink to whatever survived, it names the retained V1 surfaces a reader
/// actually reaches: Record, Changes, Account, paywall, export and the
/// post-capture choice. A guard that scans only leftovers guards nothing.
const _consumerCopyFiles = [
  'lib/product/consumer_ui_copy.dart',
  'lib/product/auditable_change_positioning.dart',
  'lib/config/production_navigation.dart',
  'lib/screens/record_screen.dart',
  'lib/screens/belief_changes_screen.dart',
  'lib/screens/paywall_screen.dart',
  'lib/screens/v1_settings_screen.dart',
  'lib/screens/export_screen.dart',
  'lib/features/recording/post_capture_choice_sheet.dart',
  'lib/features/weekly_review/weekly_review.dart',
  'lib/features/archive_ownership/archive_ownership_decision_sheet.dart',
  'lib/onboarding/onboarding_pages.dart',
  'lib/onboarding/onboarding_visuals.dart',
  'lib/billing/value_moment_paywall.dart',
  'lib/billing/pro_value_preview_model.dart',
  'lib/billing/pro_value_preview_engine.dart',
  'lib/screens/onboarding_screen.dart',
  'lib/services/capture_save_messages.dart',
  'lib/widgets/patterns/patterns_empty_view.dart',
  'lib/design/empty_archive_experience.dart',
  'docs/WIDGET_SHORTCUT_PREP.md',
  'docs/IOS_WIDGETKIT_SETUP.md',
  'docs/TODAYS_CHECK_WIDGET_QA.md',
  'lib/features/first_session/first_session_pattern_engine.dart',
  'lib/features/retention/second_session_signal_engine.dart',
  'lib/features/activation/first_three_journey_engine.dart',
  'lib/features/retention/second_session_signal_engine.dart',
];

final _manifestoCopyFiles = <String>{
  ..._consumerCopyFiles,
  'lib/api/api_exceptions.dart',
  'lib/onboarding/onboarding_visuals.dart',
};

/// Fails if consumer copy still uses the old VoiceMemory brand name.
void main() {
  test('consumer_ui_copy uses ArchiveMe brand in string literals', () {
    final source = File('lib/product/consumer_ui_copy.dart').readAsStringSync();
    expect(source, isNot(contains("'VoiceMemory")));
    expect(source, contains('ArchiveMe'));
  });

  // A deleted surface used to fail this suite once per missing file, which
  // buried real violations under hundreds of PathNotFoundExceptions and let
  // coverage rot unnoticed. Drift is now one readable failure.
  test('every guarded copy file still exists', () {
    final missing = [
      ..._consumerCopyFiles,
      ..._manifestoCopyFiles,
    ].where((path) => !File(path).existsSync()).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'These files are guarded for banned consumer copy but no longer '
          'exist. Delete the entry if the surface is gone, or repoint it if '
          'the surface moved:\n${missing.join('\n')}',
    );
  });

  for (final path in _consumerCopyFiles) {
    if (_excludedFromBannedWordScan.contains(path)) continue;
    if (!File(path).existsSync()) continue;

    test('$path has no banned consumer jargon in string literals', () {
      final source = File(path).readAsStringSync();
      final violations = _scanBannedWords(source, path, _bannedPatterns);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('$path has no companion or therapy-style copy in string literals', () {
      if (_companionCopyAllowedFiles.contains(path)) return;
      final source = File(path).readAsStringSync();
      final violations = _scanBannedWords(
        source,
        path,
        _companionBannedPatterns,
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }

  for (final path in _manifestoCopyFiles) {
    if (path.startsWith('docs/')) continue;
    if (!File(path).existsSync()) continue;
    test('$path uses manifesto-aligned microcopy', () {
      final source = File(path).readAsStringSync();
      final violations = _scanBannedWords(
        source,
        path,
        _legacyMicrocopyPatterns,
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }
}

List<String> _scanBannedWords(
  String source,
  String path,
  Map<String, String> patterns,
) {
  final violations = <String>[];
  final literalPattern = RegExp(r"'([^']*)'");

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ')) continue;
    if (trimmed.startsWith('//')) continue;

    if (trimmed.contains(r'${')) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains('/')) continue;
      if (value.contains(r'${')) continue;
      if (value.startsWith('screenshot-') ||
          RegExp(r'^[bs]\d+$').hasMatch(value)) {
        continue;
      }
      if (value.startsWith('value_moment_') || value.startsWith('PAYWALL_')) {
        continue;
      }
      if (value.startsWith('contradiction:') ||
          value.startsWith('pattern-shift:') ||
          value.startsWith('pattern:') ||
          value.startsWith('theme:') ||
          value.startsWith('chapter:') ||
          value.startsWith('evo-') ||
          value.startsWith('blind-')) {
        continue;
      }
      if (const {
        'belief',
        'themes',
        'chapterIds',
        'count',
        'lastId',
      }.contains(value)) {
        continue;
      }
      if (_isInternalIdentifier(value)) continue;

      for (final entry in patterns.entries) {
        final re = RegExp(entry.key, caseSensitive: false);
        if (!re.hasMatch(value)) continue;

        if (entry.value == 'evidence' && _evidenceAllowed(value)) continue;
        if (entry.value == 'archive' && _archiveAllowed(value)) continue;
        if (entry.value == 'chat' && _chatAllowed(value)) continue;
        if (entry.value == 'therapy' && _therapyAllowed(value)) continue;
        if (entry.value == 'journal' && _journalAllowed(value)) continue;

        violations.add('$path: banned "${entry.value}" in "$value"');
      }
    }
  }

  return violations;
}

bool _evidenceAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('based on') ||
      lower.contains('reflection') ||
      lower.contains('moment');
}

bool _archiveAllowed(String value) {
  if (value.contains('ArchiveMe')) return true;
  final lower = value.toLowerCase();
  if (lower.contains('archive timeline')) return true;
  if (lower.contains('archive review')) return true;
  if (lower.contains('ask my archive')) return true;
  if (lower.contains('your archive')) return true;
  if (lower.contains('longer archive history')) return true;
  if (lower.contains('preserving your archive')) return true;
  if (lower.contains('evidence archive')) return true;
  if (lower.contains('clean up archive')) return true;
  if (lower == 'view archive') return true;
  if (lower == 'start my archive') return true;
  if (lower.contains('archive this signal')) return true;
  return false;
}

bool _chatAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('not a chat') || lower.contains('not more chat');
}

bool _therapyAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('not therapy');
}

bool _journalAllowed(String value) {
  final lower = value.toLowerCase();
  return lower.contains('journals remember') || lower.contains('journaling');
}

bool _isInternalIdentifier(String value) {
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value);
}
