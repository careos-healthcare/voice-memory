import 'package:archiveme_mobile/core/services/activity_metadata_service.dart';
import 'package:archiveme_mobile/core/services/location_service.dart';
import 'package:archiveme_mobile/core/services/media_picker_service.dart';
import 'package:archiveme_mobile/core/services/rich_import_permission_client.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/controllers/entry_controller.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/rich_import_copy.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/providers/time_of_day_prompt_provider.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/widgets/actionable_empty_state.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a time-of-day prompt and the three import chips', (
    tester,
  ) async {
    const cases = <(int, String)>[
      (8, 'Morning Reflection'),
      (13, 'Midday Check-In'),
      (20, 'Evening Debrief'),
    ];

    for (final (hour, title) in cases) {
      await _pump(
        tester,
        hour: hour,
        controller: _controller(),
        onDraft: (_) {},
      );
      expect(find.text(title), findsOneWidget);
      expect(find.text(RichImportCopy.addRecentPhoto), findsOneWidget);
      expect(find.text(RichImportCopy.attachLocation), findsOneWidget);
      expect(find.text(RichImportCopy.logCurrentActivity), findsOneWidget);
    }
  });

  testWidgets(
    'photo chip asks before reading the gallery, then saves a draft',
    (
      tester,
    ) async {
      final events = <String>[];
      final drafts = <JournalEntry>[];
      await _pump(
        tester,
        hour: 8,
        controller: _controller(
          events: events,
          asset: const RecentMediaAsset(
            localPath: '/tmp/recent.jpg',
            mimeType: 'image/jpeg',
            filename: 'recent.jpg',
          ),
        ),
        onDraft: drafts.add,
      );

      await tester.tap(find.byKey(const Key('rich_import_photo_chip')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('soft_permission_overlay')), findsOneWidget);
      expect(events, isEmpty);
      expect(drafts, isEmpty);

      await tester.tap(find.byKey(const Key('soft_permission_continue')));
      await tester.pumpAndSettle();

      expect(events, ['permission:photos', 'gallery']);
      expect(drafts, hasLength(1));
      final draft = drafts.single;
      expect(draft.transcript, contains('Morning Reflection'));
      expect(draft.transcript, contains('recent photo'));
      expect(draft.transcript.trim(), isNotEmpty);
      expect(draft.imageEvidence?.localPath, '/tmp/recent.jpg');
      expect(draft.captureSource, 'rich_import_photo');
      expect(draft.syncStatus, SyncStatus.localOnly);
    },
  );

  testWidgets('declining the soft prompt does not touch photos or save', (
    tester,
  ) async {
    final events = <String>[];
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 8,
      controller: _controller(events: events),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_photo_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('soft_permission_not_now')));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(drafts, isEmpty);
    expect(find.byKey(const Key('rich_import_failure_overlay')), findsNothing);
  });

  testWidgets('unavailable photo permission fails in an overlay', (
    tester,
  ) async {
    final events = <String>[];
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 8,
      controller: _controller(
        events: events,
        permission: PermissionOutcome.unavailable,
        asset: const RecentMediaAsset(
          localPath: '/tmp/recent.jpg',
          mimeType: 'image/jpeg',
        ),
      ),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_photo_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('soft_permission_continue')));
    await tester.pumpAndSettle();

    expect(events, ['permission:photos']);
    expect(find.text(RichImportCopy.photosUnavailable), findsOneWidget);
    expect(drafts, isEmpty);
  });

  testWidgets('location chip saves a neighborhood draft without typed text', (
    tester,
  ) async {
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 13,
      controller: _controller(
        location: LocationService(
          positions: _FixedPosition(
            const GeoPoint(latitude: 37.76, longitude: -122.42),
          ),
          geocoder: _NamedGeocoder('Mission District'),
        ),
      ),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_location_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('soft_permission_overlay')), findsOneWidget);
    await tester.tap(find.byKey(const Key('soft_permission_continue')));
    await tester.pumpAndSettle();

    expect(drafts, hasLength(1));
    expect(drafts.single.transcript, contains('Midday Check-In'));
    expect(drafts.single.transcript, contains('Near Mission District.'));
    expect(drafts.single.captureSource, 'rich_import_location');
    expect(drafts.single.syncStatus, SyncStatus.localOnly);
  });

  testWidgets('location chip still saves when reverse geocode is offline', (
    tester,
  ) async {
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 13,
      controller: _controller(
        location: LocationService(
          positions: _FixedPosition(
            const GeoPoint(latitude: 37.76, longitude: -122.42),
          ),
          geocoder: _OfflineGeocoder(),
        ),
      ),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_location_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('soft_permission_continue')));
    await tester.pumpAndSettle();

    expect(drafts.single.transcript, contains('Near 37.76, -122.42.'));
  });

  testWidgets('activity chip saves a detected activity in one tap', (
    tester,
  ) async {
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 20,
      controller: _controller(
        activity: ActivityMetadataService(
          detector: _FixedActivity(
            const ActivityMetadata(
              label: 'Evening wind-down',
              source: ActivitySource.detected,
            ),
          ),
        ),
      ),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_activity_chip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('soft_permission_overlay')), findsNothing);
    expect(drafts, hasLength(1));
    expect(drafts.single.transcript, contains('Evening Debrief'));
    expect(
      drafts.single.transcript,
      contains('Current activity: Evening wind-down.'),
    );
    expect(drafts.single.captureSource, 'rich_import_activity');
  });

  testWidgets('activity chip offers a picker when nothing is detected', (
    tester,
  ) async {
    final drafts = <JournalEntry>[];
    await _pump(
      tester,
      hour: 20,
      controller: _controller(
        activity: ActivityMetadataService(detector: _FixedActivity(null)),
      ),
      onDraft: drafts.add,
    );

    await tester.tap(find.byKey(const Key('rich_import_activity_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity_picker_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity_option_Walking')));
    await tester.pumpAndSettle();

    expect(drafts.single.transcript, contains('Current activity: Walking.'));
    expect(drafts.single.captureContextTag, 'Walking');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required int hour,
  required EntryController controller,
  required void Function(JournalEntry entry) onDraft,
}) {
  return tester.pumpWidget(
    ProviderScope(
      key: ValueKey(hour),
      overrides: [
        timeOfDayPromptProvider.overrideWith(
          () => TimeOfDayPromptProvider(
            clock: () => DateTime(2026, 6, 1, hour),
          ),
        ),
        entryControllerProvider.overrideWithValue(controller),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ActionableEmptyState(onDraftCreated: onDraft),
        ),
      ),
    ),
  );
}

EntryController _controller({
  List<String>? events,
  PermissionOutcome permission = PermissionOutcome.granted,
  RecentMediaAsset? asset,
  LocationService? location,
  ActivityMetadataService? activity,
}) {
  final log = events ?? <String>[];
  return EntryController(
    writer: (_) async {},
    permissions: _ScriptedPermissions(permission, log),
    mediaPicker: MediaPickerService(source: _ScriptedGallery(log, asset)),
    locationService: location,
    activityService: activity,
    newId: _IdSequence().next,
  );
}

class _IdSequence {
  var _n = 0;

  String next() => 'id-${_n++}';
}

class _ScriptedPermissions implements SystemPermissionClient {
  _ScriptedPermissions(this.outcome, this.events);

  final PermissionOutcome outcome;
  final List<String> events;

  @override
  Future<PermissionOutcome> request(SoftPermissionKind kind) async {
    events.add('permission:${kind.name}');
    return outcome;
  }
}

class _ScriptedGallery extends RecentGallerySource {
  _ScriptedGallery(this.events, this.asset);

  final List<String> events;
  final RecentMediaAsset? asset;

  @override
  Future<RecentMediaAsset?> latestAsset() async {
    events.add('gallery');
    return asset;
  }
}

class _FixedPosition extends DevicePositionSource {
  _FixedPosition(this.point);

  final GeoPoint point;

  @override
  Future<GeoPoint?> currentPosition() async => point;
}

class _NamedGeocoder extends NeighborhoodGeocoder {
  _NamedGeocoder(this.name);

  final String name;

  @override
  Future<String?> neighborhoodName(GeoPoint point) async => name;
}

class _OfflineGeocoder extends NeighborhoodGeocoder {
  @override
  Future<String?> neighborhoodName(GeoPoint point) async {
    throw StateError('offline');
  }
}

class _FixedActivity extends ActivityDetector {
  _FixedActivity(this.value);

  final ActivityMetadata? value;

  @override
  Future<ActivityMetadata?> detect() async => value;
}
