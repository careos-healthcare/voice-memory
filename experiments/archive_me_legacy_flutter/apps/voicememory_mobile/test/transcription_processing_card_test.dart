import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_job.dart';
import 'package:voicememory_mobile/widgets/transcription_processing_card.dart';

void main() {
  testWidgets(
    'shows accessible processing duration without blocking controls',
    (tester) async {
      final now = DateTime.utc(2026, 7, 24);
      final job = TranscriptionJob(
        id: 'job-1',
        entryId: 'entry-1',
        audioPath: '/queue/job.wav',
        sourceFileName: 'recording.wav',
        durationSeconds: 125,
        status: TranscriptionJobStatus.processing,
        createdAt: now,
        updatedAt: now,
        attemptCount: 1,
        leaseToken: 'lease',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
      );
      var captures = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TranscriptionProcessingCard(job: job),
                FilledButton(
                  onPressed: () => captures++,
                  child: const Text('Record another'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Processing audio (2:05)…'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TranscriptionProcessingCard)),
        matchesSemantics(
          label: 'Processing audio (2:05)…',
          isLiveRegion: true,
          hasEnabledState: false,
        ),
      );
      await tester.tap(find.text('Record another'));
      expect(captures, 1);
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
