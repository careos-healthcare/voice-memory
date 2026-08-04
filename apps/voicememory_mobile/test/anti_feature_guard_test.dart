import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:voicememory_mobile/features/monetization/domain/generated/monetization_policy.g.dart';
import 'package:voicememory_mobile/product/archive_me_v1_product_contract.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/router/primary_destination.dart';
import 'package:voicememory_mobile/router/route_catalog.dart';

/// Repository root, relative to the Flutter package the tests run from.
const _repoRoot = '../..';

final Map<String, dynamic> _contract = jsonDecode(
  File(
    '$_repoRoot/config/product/archive_me_v1_contract.json',
  ).readAsStringSync(),
);

Map<String, dynamic> get _guard =>
    _contract['antiFeatureGuard'] as Map<String, dynamic>;

List<String> _strings(Object? value) =>
    (value as List<dynamic>).cast<String>().toList();

/// The rejected directions, exactly as Part 12 named them.
const _requiredDirections = <String>{
  'fifth-primary-tab',
  'multiple-journals',
  'places-location-journaling',
  'streak-pressure',
  'rich-media-parity',
  'ai-companion-persona',
  'therapy-claims',
  'diagnosis',
  'generic-chat',
  'generic-memory-assistant',
  'memory-graph',
  'blind-spots',
  'analyst-dashboard',
  'life-os',
  'future-simulation',
  'ocr',
  'document-ingestion',
  'health-integration',
  'ble',
  'webrtc',
  'social-community',
  'guide-libraries',
  'mood-tracker-identity',
  'lifetime-subscription',
  'entry-count-value-promises',
};

/// The claim scanner the enforcement script runs, reimplemented here against
/// the same contract so a Dart-side change is caught without Node.
class _ClaimScanner {
  _ClaimScanner()
    : _denial = RegExp(_guard['claimDenial'] as String, caseSensitive: false),
      _claims = [
        for (final claim
            in (_guard['prohibitedPositioningClaims'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          (
            id: claim['id'] as String,
            pattern: RegExp(claim['pattern'] as String, caseSensitive: false),
          ),
      ];

  final RegExp _denial;
  final List<({String id, RegExp pattern})> _claims;

  /// Direction ids claimed by [text], ignoring any claim its own sentence
  /// denies. Callers pass one primary slot or one sentence, never a whole file.
  List<String> claimsIn(String text) {
    final hits = <String>{};
    for (final sentence in text.split(RegExp(r'(?<=[.!?])\s+|\n'))) {
      if (sentence.trim().isEmpty) continue;
      for (final claim in _claims) {
        for (final match in claim.pattern.allMatches(sentence)) {
          if (_denial.hasMatch(sentence.substring(0, match.start))) continue;
          hits.add(claim.id);
          break;
        }
      }
    }
    return hits.toList()..sort();
  }
}

int _dartFileCount(String directory) {
  final handle = Directory('$_repoRoot/$directory');
  if (!handle.existsSync()) return 0;
  return handle
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .length;
}

void main() {
  final scanner = _ClaimScanner();

  group('the contract encodes every rejected direction', () {
    test('all 25 directions are present with an enforcement mechanism', () {
      final entries =
          (_contract['prohibitedProductDirections'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final ids = entries.map((entry) => entry['id'] as String).toSet();

      expect(ids, containsAll(_requiredDirections));
      expect(_requiredDirections, containsAll(ids));
      for (final entry in entries) {
        expect(
          entry['enforcedBy'],
          isNotEmpty,
          reason: '${entry['id']} declares no enforcement mechanism',
        );
      }
    });

    test('every claim pattern maps to a declared direction', () {
      final ids = (_contract['prohibitedProductDirections'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((entry) => entry['id'] as String)
          .toSet();
      for (final claim
          in (_guard['prohibitedPositioningClaims'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        expect(ids, contains(claim['id']));
      }
    });
  });

  group('structural guards', () {
    test('there is no fifth primary tab', () {
      expect(RouteCatalog.primaryRoutes, hasLength(_guard['primaryTabCount']));
      expect(PrimaryDestination.values, hasLength(_guard['primaryTabCount']));
      expect(
        _strings(_contract['allowedPrimaryRoutes']),
        hasLength(_guard['primaryTabCount']),
      );
      expect(
        ArchiveMeV1ProductContract.primaryRoutes,
        RouteCatalog.primaryRoutes,
      );
    });

    test('no rejected route is reachable by a consumer', () {
      for (final route in _strings(_guard['prohibitedRoutePaths'])) {
        expect(
          ArchiveMeV1ProductContract.isConsumerRouteAllowed(route),
          isFalse,
          reason: '$route must not be reachable',
        );
      }
    });

    test('rejected production modules hold no Dart code', () {
      final featureRoot = _guard['productionFeatureRoot'] as String;
      for (final name in _strings(
        _guard['prohibitedProductionFeatureDirectories'],
      )) {
        expect(
          _dartFileCount('$featureRoot/$name'),
          0,
          reason: '$featureRoot/$name has returned',
        );
      }
      for (final directory in _strings(
        _guard['prohibitedProductionDirectories'],
      )) {
        expect(_dartFileCount(directory), 0, reason: '$directory has returned');
      }
    });

    test('no lifetime package is sold', () {
      expect(
        MonetizationPolicy.blockedCurrentPackageKinds,
        contains('lifetime'),
      );
      expect(
        MonetizationPolicy.currentOfferingPackageKinds,
        isNot(contains('lifetime')),
      );
      expect(
        _strings(_guard['prohibitedMonetizationPackageKinds']),
        contains('lifetime'),
      );
    });
  });

  group('the claim scanner catches a rejected direction', () {
    const violations = <String, String>{
      'multiple-journals': 'Keep multiple journals, one for each part of life.',
      'places-location-journaling':
          'Open the Places tab to see where you journal most.',
      'streak-pressure': 'Keep your 30 day streak alive.',
      'rich-media-parity': 'Attach photos and videos to every entry.',
      'ai-companion-persona': 'Meet your AI companion.',
      'therapy-claims': 'Therapy that fits in your pocket.',
      'diagnosis': 'Get a diagnosis from your own words.',
      'generic-chat': 'Chat with your saved moments any time.',
      'generic-memory-assistant': 'Your memory assistant for everything.',
      'memory-graph': 'Explore the memory graph of your life.',
      'blind-spots': 'Reveal your blind spots.',
      'analyst-dashboard': 'Open your analyst dashboard.',
      'life-os': 'The life operating system for your mind.',
      'future-simulation': 'Simulate your future from what you saved.',
      'ocr': 'Scan documents straight into your timeline.',
      'document-ingestion': 'Import documents and let ArchiveMe read them.',
      'health-integration': 'Pull health data from HealthKit automatically.',
      'ble': 'Pair over Bluetooth with your other devices.',
      'webrtc': 'Talk live over WebRTC.',
      'social-community': 'Share with friends in the community feed.',
      'guide-libraries': 'Browse a library of guides and courses.',
      'mood-tracker-identity': 'Track your mood every single day.',
      'lifetime-subscription': 'Buy the lifetime plan once and keep it.',
      'entry-count-value-promises':
          'Unlock the real value after 100 entries saved.',
    };

    for (final entry in violations.entries) {
      test('catches ${entry.key}', () {
        expect(
          scanner.claimsIn(entry.value),
          contains(entry.key),
          reason: 'guard missed: "${entry.value}"',
        );
      });
    }
  });

  group('the guard does not fire on legitimate code or copy', () {
    test('production directories that merely share a word keep their code', () {
      // A substring scan for "journal", "chat", "memory", "media" or "share"
      // would delete real V1 code. The guard matches whole directory names
      // from an explicit list instead, so these stay untouched.
      for (final directory in _strings(
        _guard['legitimateProductionDirectories'],
      )) {
        expect(
          _dartFileCount(directory),
          greaterThan(0),
          reason: '$directory is allowlisted but empty',
        );
        expect(
          _strings(_guard['prohibitedProductionFeatureDirectories']),
          isNot(contains(directory.split('/').last)),
        );
      }
    });

    test('a legitimate identifier containing a rejected word is not a claim', () {
      // Each of these is real production code or configuration whose name or
      // value contains a word the prohibited list uses.
      const legitimate = <String, String>{
        'lib/features/journal (5 Dart files)':
            'apps/voicememory_mobile/lib/features/journal/domain/saved_moment.dart',
        'lib/features/chat_differentiation (3 Dart files)':
            'apps/voicememory_mobile/lib/features/chat_differentiation/chat_differentiation_engine.dart',
        'lib/features/memory (38 Dart files)':
            'apps/voicememory_mobile/lib/features/memory/memory_resurfacing_engine.dart',
        'grandfathered product id': 'archive_loop_pro_lifetime',
        'Archive health copy': VisibleArchiveProofCopy.archiveHealthTitle,
        'Health topic chip': 'Health',
        'ChatGPT differentiation line':
            LandingAppContinuityCopy.chatGptDifferentiation,
        'Changes lead': ConsumerUiCopy.changesScreenLead,
      };

      for (final entry in legitimate.entries) {
        expect(
          scanner.claimsIn(entry.value),
          isEmpty,
          reason: 'guard falsely flagged ${entry.key}: "${entry.value}"',
        );
      }
    });

    test('the grandfathered lifetime product id stays legal', () {
      // MonetizationPolicy must keep honouring an old lifetime purchase while
      // never selling a new one. A naive "lifetime" scan would break that.
      expect(
        MonetizationPolicy.legacyGrandfatheredProductIds,
        contains('archive_loop_pro_lifetime'),
      );
      expect(
        scanner.claimsIn(
          MonetizationPolicy.legacyGrandfatheredProductIds.join(' '),
        ),
        isEmpty,
      );
    });

    test('the excluded-route list may name the routes it excludes', () {
      // ArchiveMeV1ProductContract lists '/blind-spots' and '/life-os' so the
      // router can refuse them. Naming a route in order to block it is not a
      // claim, and the scanner never reads that list.
      expect(
        ArchiveMeV1ProductContract.excludedConsumerRoutes,
        containsAll(<String>['/blind-spots', '/life-os', '/archive-analyst']),
      );
      for (final route in ArchiveMeV1ProductContract.excludedConsumerRoutes) {
        expect(
          ArchiveMeV1ProductContract.isConsumerRouteAllowed(route),
          isFalse,
        );
      }
    });

    test('the shipped positioning copy sources are clean', () {
      for (final source in _strings(_guard['positioningCopySources'])) {
        final file = File('$_repoRoot/$source');
        expect(file.existsSync(), isTrue, reason: 'missing source: $source');
        final markdown = source.endsWith('.md');
        final prohibitedHeading = RegExp(
          _guard['prohibitedMarkdownSectionHeadings'] as String,
          caseSensitive: false,
        );
        var skipping = false;
        for (final line in file.readAsStringSync().split('\n')) {
          if (markdown && line.startsWith('#')) {
            skipping = prohibitedHeading.hasMatch(line);
            continue;
          }
          if (skipping) continue;
          expect(
            scanner.claimsIn(line),
            isEmpty,
            reason: '$source claims a rejected direction in: $line',
          );
        }
      }
    });
  });
}
