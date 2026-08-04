import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/feature_discovery/contextual_feature_discovery_banner.dart';
import 'package:voicememory_mobile/services/feature_discovery/feature_discovery_service.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_secondary_nav_links.dart';

import 'support/widget_test_pump.dart';

void main() {
  late Directory directory;
  late MobilePrefsStore prefs;
  late FeatureDiscoveryService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('feature_discovery_');
    prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
    service = FeatureDiscoveryService(
      prefs: prefs,
      clock: () => DateTime.utc(2026, 7, 26, 12),
    );
  });

  tearDown(() => directory.delete(recursive: true));

  test('processed entry exposes Insights Ready only once', () async {
    const context = FeatureDiscoveryContext(
      moment: FeatureDiscoveryMoment.afterEntryProcessed,
      entryCount: 1,
    );

    final first = await service.nextSuggestion(context);
    expect(first?.feature, DiscoverableFeature.insightsReady);
    expect(first?.title, 'Insights ready');
    await service.markExposed(first!.feature);

    final reloaded = FeatureDiscoveryService(prefs: prefs);
    expect(await reloaded.nextSuggestion(context), isNull);
  });

  test('three-entry milestone advances discovery to Life Story', () async {
    await service.markExposed(DiscoverableFeature.insightsReady);

    final suggestion = await service.nextSuggestion(
      const FeatureDiscoveryContext(
        moment: FeatureDiscoveryMoment.afterEntryProcessed,
        entryCount: 3,
      ),
    );

    expect(suggestion?.feature, DiscoverableFeature.lifeStory);
    expect(suggestion?.route, '/life-os');
    expect(suggestion?.reason, 'journal_milestone_3');
  });

  test('dismissal persists and reveals the next eligible feature', () async {
    await service.dismiss(DiscoverableFeature.lifeStory);

    final suggestion = await service.nextSuggestion(
      const FeatureDiscoveryContext(
        moment: FeatureDiscoveryMoment.dashboard,
        entryCount: 5,
      ),
    );

    expect(suggestion?.feature, DiscoverableFeature.archiveIntelligence);
    expect(suggestion?.route, '/archive-analyst');
  });

  testWidgets('banner is non-modal, dismissible, and records its CTA', (
    tester,
  ) async {
    final widgetService = FeatureDiscoveryService(prefs: _MemoryPrefs());
    FeatureDiscoverySuggestion? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextualFeatureDiscoveryBanner(
            service: widgetService,
            discoveryContext: const FeatureDiscoveryContext(
              moment: FeatureDiscoveryMoment.afterEntryProcessed,
              entryCount: 1,
            ),
            onOpen: (suggestion) => opened = suggestion,
          ),
        ),
      ),
    );
    await pumpUntilFound(
      tester,
      find.byKey(const Key('feature_discovery_insights_ready')),
    );

    expect(
      find.byKey(const Key('feature_discovery_insights_ready')),
      findsOneWidget,
    );
    expect(find.text('Insights ready'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('feature_discovery_open_insights_ready')),
    );
    await tester.pump();

    expect(opened?.feature, DiscoverableFeature.insightsReady);
    final state = await widgetService.stateForTest();
    expect(
      (state['insights_ready'] as Map<String, dynamic>)['completed'],
      isTrue,
    );
  });

  testWidgets('dashboard prominently links both consolidated engines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ArchiveSecondaryNavLinks(entryCount: 5)),
      ),
    );

    expect(
      find.text('Explore Life Story & Archive Intelligence'),
      findsOneWidget,
    );
  });
}

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('unused_feature_discovery_prefs.json'));

  final Map<String, Map<String, dynamic>> _maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    final value = _maps[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>> updateMap(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>? current) transform,
  ) async {
    final next = transform(await readMap(key));
    _maps[key] = Map<String, dynamic>.from(next);
    return next;
  }

  @override
  Future<void> remove(String key) async {
    _maps.remove(key);
  }
}
