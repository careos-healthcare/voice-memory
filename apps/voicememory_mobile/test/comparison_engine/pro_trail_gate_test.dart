import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/pro_trail_gate.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';

ArchiveMomentRecord _moment(String id, String words) => ArchiveMomentRecord(
      id: id,
      createdAt: DateTime.utc(2026, 6, 10),
      savedWords: words,
    );

void main() {
  group('ProTrailGate', () {
    test('free tier keeps only the most recent historical moment', () {
      final moments = [
        _moment('1', 'said yes again'),
        _moment('2', 'said yes before checking'),
        _moment('3', 'said yes at work'),
      ];

      final visible = ProTrailGate.visibleHistoricalMoments(
        moments: moments,
        isPro: false,
      );

      expect(visible.length, ProTrailGate.freeHistoricalMomentLimit);
      expect(visible.single.id, '3');
    });

    test('pro tier keeps the full historical thread', () {
      final moments = [
        _moment('1', 'said yes again'),
        _moment('2', 'said yes before checking'),
      ];

      final visible = ProTrailGate.visibleHistoricalMoments(
        moments: moments,
        isPro: true,
      );

      expect(visible.length, 2);
    });

    test('conversion milestone requires meaningful pattern on free tier', () {
      expect(
        ProTrailGate.hasReachedConversionMilestone(
          alignmentState: PatternState.possibleRepeat,
          totalMomentCount: 2,
          isPro: false,
        ),
        isTrue,
      );
      expect(
        ProTrailGate.hasReachedConversionMilestone(
          alignmentState: PatternState.earlySignal,
          totalMomentCount: 2,
          isPro: false,
        ),
        isFalse,
      );
      expect(
        ProTrailGate.hasReachedConversionMilestone(
          alignmentState: PatternState.clearRepeat,
          totalMomentCount: 2,
          isPro: true,
        ),
        isFalse,
      );
    });

    test('shouldShowProTrailPrompt respects dismissal', () {
      expect(
        ProTrailGate.shouldShowProTrailPrompt(
          isPro: false,
          hasDismissedProTrailPrompt: false,
          alignmentState: PatternState.clearRepeat,
          totalMomentCount: 3,
        ),
        isTrue,
      );
      expect(
        ProTrailGate.shouldShowProTrailPrompt(
          isPro: false,
          hasDismissedProTrailPrompt: true,
          alignmentState: PatternState.clearRepeat,
          totalMomentCount: 3,
        ),
        isFalse,
      );
    });

    test('conversionHeadline uses canonical pro trail promise', () {
      expect(
        ProTrailGate.conversionHeadline,
        ProConversionAuditCopy.proTrailCanonical,
      );
    });
  });
}
