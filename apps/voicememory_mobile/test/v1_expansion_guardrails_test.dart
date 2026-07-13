import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/onboarding/first_proof_journey_copy.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:voicememory_mobile/features/release_candidate/v1_revenue_focus_policy.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_core_product_sentence.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_scope_guard_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';

bool _isNegatedClaim(String value, String phrase) {
  final lower = value.toLowerCase();
  final needle = phrase.toLowerCase();
  var start = 0;
  var found = false;
  while (true) {
    final idx = lower.indexOf(needle, start);
    if (idx < 0) return found;
    found = true;
    final before = lower.substring(0, idx).trimRight();
    final negated = before.endsWith('not') ||
        before.endsWith('not a') ||
        before.endsWith('not an') ||
        before.endsWith('no');
    if (!negated) return false;
    start = idx + needle.length;
  }
}

Iterable<String> _stringLiteralsFromDartSource(String source) sync* {
  final literalPattern = RegExp(r"'([^']*)'");
  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ') || trimmed.startsWith('//')) continue;
    if (trimmed.contains(r'${')) continue;
    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains('/')) continue;
      if (RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value)) continue;
      yield value;
    }
  }
}

bool _isProhibitionContext(String line) {
  final lower = line.toLowerCase();
  return lower.contains('do not include') ||
      lower.contains('do not claim') ||
      lower.contains('not a diary') ||
      lower.contains('no daily journal') ||
      lower.contains('not chatgpt') ||
      lower.contains('not homework') ||
      lower.startsWith('- therapy') ||
      lower.contains('therapy, diagnosis');
}

Iterable<String> _consumerLinesFromMarkdown(String source) sync* {
  var inDoNotInclude = false;
  for (final rawLine in source.split('\n')) {
    final line = rawLine.trim();
    if (line.toLowerCase().startsWith('## do not include')) {
      inDoNotInclude = true;
      continue;
    }
    if (inDoNotInclude) {
      if (line.startsWith('## ')) inDoNotInclude = false;
      continue;
    }
    if (line.isEmpty || line.startsWith('#')) continue;
    if (_isProhibitionContext(line)) continue;
    yield line;
  }
}

bool _mentionsLiveFocusPhrase(String blob, String phrase) {
  final lower = blob.toLowerCase();
  switch (phrase) {
    case 'first proof':
      return lower.contains('first proof') || lower.contains('first useful proof');
    case 'longer trail':
      return lower.contains('longer trail') ||
          lower.contains('longer proof trail');
    case 'evidence over time':
      return lower.contains('evidence over time');
    default:
      return lower.contains(phrase);
  }
}

void main() {
  group('V1 scope guard', () {
    test('launch copy does not position ArchiveMe as broad journal or assistant', () {
      for (final relativePath in V1ScopeGuardCopy.launchCopyFilePaths) {
        final file = File(relativePath);
        expect(file.existsSync(), isTrue, reason: 'missing $relativePath');
        final source = file.readAsStringSync();
        final literals = relativePath.endsWith('.md')
            ? _consumerLinesFromMarkdown(source).toList()
            : _stringLiteralsFromDartSource(source).toList();
        for (final literal in literals) {
          final content = literal.toLowerCase();
          for (final claim in V1ScopeGuardCopy.bannedPositioningClaims) {
            if (!content.contains(claim)) continue;
            expect(
              _isNegatedClaim(literal, claim),
              isTrue,
              reason: '$relativePath positions as "$claim" in "$literal"',
            );
          }
        }
      }
    });

    test('banned positioning list matches V1 guardrail spec', () {
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('generic journal'));
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('diary dashboard'));
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('therapy'));
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('coach'));
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('treatment'));
      expect(V1ScopeGuardCopy.bannedPositioningClaims, contains('diagnosis'));
      expect(
        V1ScopeGuardCopy.bannedPositioningClaims,
        contains('chatgpt replacement'),
      );
      expect(
        V1ScopeGuardCopy.bannedPositioningClaims,
        contains('productivity dashboard'),
      );
      expect(
        V1ScopeGuardCopy.bannedPositioningClaims,
        contains('life operating system'),
      );
    });
  });

  group('Navigation simplicity', () {
    test('primary bottom nav is Record, Archive, Account only', () {
      final mainShell = File('lib/widgets/main_shell.dart').readAsStringSync();
      expect(
        RegExp(r'NavigationDestination\s*\(').allMatches(mainShell).length,
        3,
      );
      expect(mainShell, contains("label: 'Record'"));
      expect(mainShell, contains('ConsumerUiCopy.patternsTabLabel'));
      expect(mainShell, contains("label: 'Account'"));
      expect(mainShell.toLowerCase(), isNot(contains("label: 'discover'")));
      expect(mainShell.toLowerCase(), isNot(contains("label: 'timeline'")));
      expect(mainShell.toLowerCase(), isNot(contains("label: 'search'")));
      expect(ConsumerUiCopy.patternsTabLabel, 'Archive');
    });

    test('router shell has three primary branches not six equal tabs', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      final shellSection = router.split('StatefulShellRoute').skip(1).first;
      expect(
        RegExp(r'StatefulShellBranch\s*\(').allMatches(shellSection).length,
        3,
      );
    });
  });

  group('First-proof journey', () {
    test('expects save, compare, thread, and longer-trail pro value', () {
      expect(RecordFirstUsePromptCopy.title, 'Save one real moment.');
      expect(FirstProofJourneyCopy.strip, contains('1 Save'));
      expect(FirstProofJourneyCopy.strip, contains('2 Compare'));
      expect(FirstProofJourneyCopy.strip, contains('3 First thread'));
      expect(V1CoreProductSentence.line, contains('Pro keeps the longer trail'));

      final proBlob = [
        PaywallAlignmentCopy.headline,
        PaywallAlignmentCopy.body,
        PaywallAlignmentCopy.lockMomentPaidReason,
        PaywallValueSharpeningCopy.cta,
      ].join(' ').toLowerCase();
      expect(proBlob, contains('longer'));
      expect(proBlob, contains('trail'));
    });

    test('avoids streak and homework language in first-proof surfaces', () {
      final blob = [
        FirstProofJourneyCopy.strip,
        FirstProofJourneyCopy.helper,
        RecordFirstUsePromptCopy.title,
        RecordFirstUsePromptCopy.body,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('streak')));
      expect(blob, isNot(contains('homework')));
      expect(blob, isNot(contains('daily challenge')));
      expect(blob, isNot(contains('must record every day')));
    });
  });

  group('V1 expansion gates doc', () {
    test('doc blocks expansion until proof and lists gated future ideas', () {
      final doc =
          File(V1ExpansionGateCopy.expansionGatesDocPath).readAsStringSync();
      expect(doc, contains(V1ExpansionGateCopy.expansionBlockedLine));
      expect(doc, contains(V1ExpansionGateCopy.sharperV1MoveLine));
      expect(doc, contains(V1CoreProductSentence.line));
      for (final idea in V1ExpansionGateCopy.blockedExpansionIdeas) {
        expect(doc.toLowerCase(), contains(idea.toLowerCase()));
      }
    });

    test('beta decision system is measurement-only not product expansion', () {
      final doc = File('docs/BETA_DECISION_SYSTEM.md').readAsStringSync();
      expect(doc.toLowerCase(), contains('not a user-facing product expansion'));
      expect(doc, contains('docs/V1_EXPANSION_GATES.md'));
      expect(doc.toLowerCase(), contains('do not build ask archive'));
    });
  });

  group('Future revenue guard', () {
    test('expansion gate copy module mirrors gated doc list', () {
      expect(
        V1ExpansionGateCopy.blockedExpansionIdeas.length,
        greaterThanOrEqualTo(13),
      );
      for (final idea in V1ExpansionGateCopy.blockedExpansionIdeas) {
        final doc =
            File(V1ExpansionGateCopy.expansionGatesDocPath).readAsStringSync();
        expect(doc.toLowerCase(), contains(idea.toLowerCase()));
      }
    });

    test('live V1 copy stays on first proof and trail not more AI', () {
      final liveBlob = [
        V1CoreProductSentence.line,
        PaywallAlignmentCopy.headline,
        PaywallAlignmentCopy.body,
        PaywallAlignmentCopy.lockMomentPaidReason,
        PaywallAlignmentCopy.backupBridgeBody,
        PaywallValueSharpeningCopy.proofConnectedLine,
        PaywallValueSharpeningCopy.body,
        ConsumerUiCopy.paywallHeadline,
      ].join(' ').toLowerCase();

      for (final phrase in V1ScopeGuardCopy.bannedLiveRevenuePhrases) {
        expect(liveBlob, isNot(contains(phrase)), reason: 'found "$phrase"');
      }

      var focusHits = 0;
      for (final phrase in V1ScopeGuardCopy.requiredLiveFocusPhrases) {
        if (_mentionsLiveFocusPhrase(liveBlob, phrase)) focusHits++;
      }
      expect(
        focusHits,
        greaterThanOrEqualTo(2),
        reason: 'live V1 copy should mention first proof / longer trail / evidence',
      );

      expect(
        V1RevenueFocusPolicy.hasNoBannedLiveProClaims([
          PaywallAlignmentCopy.headline,
          PaywallAlignmentCopy.body,
        ]),
        isTrue,
      );
      expect(
        V1RevenueFocusPolicy.copyMentionsAllowedPillar([
          PaywallAlignmentCopy.headline,
          PaywallAlignmentCopy.body,
        ]),
        isTrue,
      );
    });
  });
}
