import 'package:archiveme_mobile/features/post_save/moment_save_receipt_copy.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matchers for the V1 unified post-save receipt on the record screen.
abstract final class V1MomentSaveReceiptExpectations {
  V1MomentSaveReceiptExpectations._();

  static final Finder card = find.byKey(const Key('moment_save_receipt_card'));
  static final Finder title = find.byKey(
    const Key('moment_save_receipt_title'),
  );
  static final Finder transcript = find.byKey(
    const Key('moment_save_receipt_transcript'),
  );
  static final Finder recordAnother = find.byKey(
    const Key('moment_save_receipt_record_another'),
  );
  static final Finder viewArchive = find.byKey(
    const Key('moment_save_receipt_view_archive'),
  );
  static final Finder degradedBody = find.byKey(
    const Key('moment_save_receipt_degraded_body'),
  );
  static final Finder typeWhatYouSaid = find.byKey(
    const Key('moment_save_receipt_type_what_you_said'),
  );

  static void expectVisible() {
    expect(card, findsOneWidget);
    expect(find.text(MomentSaveReceiptCopy.savedOnDeviceTitle), findsOneWidget);
  }

  static void expectDegradedFallbackVisible() {
    expectVisible();
    expect(degradedBody, findsOneWidget);
    expect(
      find.text(PendingTranscriptRecoveryCopy.postSaveBody),
      findsOneWidget,
    );
    expect(typeWhatYouSaid, findsOneWidget);
    expect(find.text(VoiceCaptureCopy.typeWhatYouSaid), findsOneWidget);
    expect(recordAnother, findsOneWidget);
    expect(find.text(MomentSaveReceiptCopy.recordAnother), findsOneWidget);
  }

  static void expectNoLegacyPostSaveStack() {
    expect(find.byKey(const Key('repeat_post_save_card')), findsNothing);
    expect(find.byKey(const Key('first_proof_payoff_card')), findsNothing);
    expect(find.byKey(const Key('what_changed_v2_card')), findsNothing);
    expect(find.byKey(const Key('come_back_tomorrow_card')), findsNothing);
    expect(
      find.byKey(const Key('post_save_recorded_summary_card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('post_save_focused_actions_bar')),
      findsNothing,
    );
    expect(find.byKey(const Key('first_week_loop_card')), findsNothing);
    expect(find.byKey(const Key('belief_update_payoff_card')), findsNothing);
    expect(
      find.byKey(const Key('third_entry_belief_payoff_card')),
      findsNothing,
    );
  }
}
