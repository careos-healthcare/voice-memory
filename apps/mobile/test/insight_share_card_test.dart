import 'package:archiveme_mobile/features/insight_share/insight_share_card_builder.dart';
import 'package:archiveme_mobile/features/insight_share/insight_share_pii.dart';
import 'package:archiveme_mobile/features/insight_share/insight_share_png_metadata.dart';
import 'package:archiveme_mobile/features/referral/referral_invite_after_value.dart';
import 'package:archiveme_mobile/features/weekly_story/weekly_story_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/insight_share/insight_share_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

void main() {
  test('stripInsightSharePii removes emails phones and urls', () {
    expect(
      InsightSharePii.strip('Reach me at jane@example.com or 555-123-4567'),
      'Reach me at [redacted] or [redacted]',
    );
    expect(
      InsightSharePii.strip('See https://secret.example/path for details'),
      'See [redacted] for details',
    );
  });

  test('buildInsightShareCard uses aggregate lines only', () {
    final story = WeeklyArchiveStory(
      weekStart: DateTime(2026, 8, 4),
      weekEnd: DateTime(2026, 8, 10, 23, 59, 59),
      topThemes: const [
        WeeklyThemeLine(label: 'Work', count: 3, priorCount: 1),
      ],
      growingThemes: const [
        WeeklyThemeLine(label: 'Boundaries', count: 2, priorCount: 0),
      ],
      decliningThemes: const [],
      reflectionCountThisWeek: 4,
      hasSufficientData: true,
    );

    final model = InsightShareCardBuilder.build(story: story);
    expect(model, isNotNull);
    expect(model!.patternLines, isNot(contains(contains('@'))));
    expect(model.patternLines.first, contains('4 reflections'));
    expect(
      model.referralLink,
      ReferralInviteAfterValue.inviteLinkFor('weekly_review'),
    );
    expect(model.plainTextShare, contains(model.headline));
  });

  test('embedReferralMetadata inserts PNG chunks before IEND', () {
    // Minimal valid PNG: signature + IHDR + IEND
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00,
      0x1F, 0x15, 0xC4, 0x89,
      0x00, 0x00, 0x00, 0x00,
      0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82,
    ]);

    final enriched = InsightSharePngMetadata.embedReferralMetadata(
      png,
      referralUrl: 'https://archiveme.app/invite?ref=archive_invite&source=weekly_review',
      source: 'weekly_review',
    );

    expect(enriched.length, greaterThan(png.length));
    expect(
      String.fromCharCodes(enriched),
      contains('ArchiveMeReferral'),
    );
  });

  testWidgets('exporter shows view evidence next to the in-app headline', (
    tester,
  ) async {
    var opened = false;
    final now = DateTime.now();
    final entries = List.generate(
      6,
      (i) => JournalEntry(
        id: 'share-e$i',
        createdAt: now.subtract(Duration(days: i)),
        transcript:
            'Confidence and work reflection $i — transcript padding for evidence.',
        durationSeconds: 30,
        reflection: const Reflection(
          mood: 'calm',
          emotionalIntensity: 2,
          recurringThemes: ['confidence', 'work'],
          exactLanguagePattern: 'Confidence and work',
          concreteObservation: 'Confidence and work showed up again.',
          repeatedSignal: '',
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InsightShareExporter(
              entries: entries,
              onViewEvidence: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('insight_share_exporter')), findsOneWidget);
    expect(find.byKey(const Key('insight_share_view_evidence')), findsOneWidget);
    expect(find.byKey(const Key('insight_share_card_widget')), findsOneWidget);

    await tester.tap(find.byKey(const Key('insight_share_view_evidence')));
    await tester.pump();
    expect(opened, isTrue);
  });
}
