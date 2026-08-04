import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/connectors/data_sources_sheet.dart';
import 'package:voicememory_mobile/features/connectors/healthkit_connector.dart';
import 'package:voicememory_mobile/features/connectors/spotify_connector.dart';

void main() {
  testWidgets('toggles Health permission and Spotify OAuth states', (
    tester,
  ) async {
    final health = _FakeHealthConnector();
    final spotify = _FakeSpotifyConnector();
    var showExternal = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataSourcesSheet(
            health: health,
            spotify: spotify,
            showExternalNodes: showExternal,
            onExternalVisibilityChanged: (value) => showExternal = value,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('health-data-toggle')));
    await tester.pump();
    expect(health.enableCalls, 1);
    expect(find.text('Last synced 2026-07-27 08:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spotify-connect-button')));
    await tester.pump();
    expect(spotify.connectCalls, 1);
    expect(find.text('Disconnect'), findsOneWidget);

    await tester.tap(find.byKey(const Key('external-graph-visibility-toggle')));
    await tester.pump();
    expect(showExternal, isFalse);
  });
}

class _FakeHealthConnector implements HealthConnectorController {
  int enableCalls = 0;

  @override
  bool enabled = false;

  @override
  DateTime? lastSyncAt;

  @override
  Future<bool> enable() async {
    enableCalls++;
    enabled = true;
    lastSyncAt = DateTime(2026, 7, 27, 8);
    return true;
  }

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> syncNow() async {}
}

class _FakeSpotifyConnector implements SpotifyConnectorController {
  int connectCalls = 0;
  bool value = false;

  @override
  DateTime? lastSyncAt;

  @override
  Future<bool> get connected async => value;

  @override
  Future<void> connect() async {
    connectCalls++;
    value = true;
    lastSyncAt = DateTime(2026, 7, 27, 9);
  }

  @override
  Future<void> disconnect() async => value = false;

  @override
  Future<void> syncNow() async {}
}
