import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The approved wording, written out once as a single literal so any drift in
/// the concatenated parts of [OnDeviceArchitectureCopy] fails loudly.
///
/// Every claim here is deliberate. It replaced an earlier statement that
/// promised no cloud servers, no telemetry, and that data never leaves the
/// device — none of which is true of this app, which uploads to `/api/*` once
/// remote processing is consented to and ships Firebase Analytics wiring.
///
/// The opening block was rewritten again after an audit found no model binary
/// anywhere in the tree. It used to say "the transcripts it becomes, and the
/// reflections you read stay here", which reads as a claim that this device
/// produces them. Storage is local; production is not, except for the platform
/// speech recogniser iOS exposes through `NativeSpeechTranscription`.
const _approvedStatement =
    'Local-first storage is the architecture, not a bolted-on feature. By default your recordings, transcripts, and reflections stay in local databases here. A transcript is produced here where the system supports it, on our servers when you allow that. Privacy settings report how this build protects them, instead of asserting it here. Nothing is sent unless you choose a feature that needs it. Choose transcription or sync and your audio and transcript text go to our servers for that job only. Turn it off in Settings → Privacy and new moments stay on this device. Usage analytics carry counts and states, not your words. Journal text and transcripts are refused at that boundary rather than cleaned up afterwards. What is on this device is yours. The terms say the same thing: you keep ownership of what you record. You can export or delete your local archive at any time.';

void main() {
  group('OnDeviceArchitectureCopy', () {
    test('renders the approved statement verbatim and in order', () {
      expect(OnDeviceArchitectureCopy.fullStatement, _approvedStatement);
    });

    test('quotes are plain ASCII with no escape artifact', () {
      // A literal backslash would mean an escape leaked into the rendered
      // string; U+2019 would mean a smart quote was substituted.
      expect(OnDeviceArchitectureCopy.fullStatement, isNot(contains(r'\')));
      expect(OnDeviceArchitectureCopy.fullStatement, isNot(contains('\u2019')));
      expect(OnDeviceArchitectureCopy.fullStatement, isNot(contains('\u2018')));
    });

    test('headings are additive and not part of the statement', () {
      for (final heading in const [
        OnDeviceArchitectureCopy.architectureHeading,
        OnDeviceArchitectureCopy.remoteHeading,
        OnDeviceArchitectureCopy.ownershipHeading,
      ]) {
        expect(_approvedStatement, isNot(contains(heading)));
      }
    });

    test('sensitive promises come from the policy, not a rewrite', () {
      expect(
        OnDeviceArchitectureCopy.remoteCallout,
        startsWith(PrivacyCopyPolicy.nothingSentUnlessFeatureChosen),
      );
      expect(
        OnDeviceArchitectureCopy.ownershipControls,
        PrivacyCopyPolicy.exportDeleteAnytime,
      );
    });

    test('passes the privacy copy policy', () {
      for (final block in const [
        OnDeviceArchitectureCopy.architectureHeading,
        OnDeviceArchitectureCopy.architectureBody,
        OnDeviceArchitectureCopy.storageBody,
        OnDeviceArchitectureCopy.remoteHeading,
        OnDeviceArchitectureCopy.remoteCallout,
        OnDeviceArchitectureCopy.analyticsBody,
        OnDeviceArchitectureCopy.ownershipHeading,
        OnDeviceArchitectureCopy.ownershipBody,
        OnDeviceArchitectureCopy.ownershipControls,
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(block),
          isEmpty,
          reason: block,
        );
      }
    });

    group('claims that were removed stay removed', () {
      // Each of these was in the previous statement and is false for this
      // codebase. See the class doc for the code that contradicts them.
      test('does not deny that cloud servers exist', () {
        expect(
          OnDeviceArchitectureCopy.fullStatement.toLowerCase(),
          isNot(contains('no cloud servers')),
        );
      });

      test('does not deny telemetry', () {
        expect(
          OnDeviceArchitectureCopy.fullStatement.toLowerCase(),
          isNot(contains('no telemetry')),
        );
      });

      test('does not claim data never leaves the device', () {
        final lower = OnDeviceArchitectureCopy.fullStatement.toLowerCase();
        expect(lower, isNot(contains('never leave')));
        expect(lower, isNot(contains('never sent')));
      });

      test('does not claim a single exclusive storage engine', () {
        final lower = OnDeviceArchitectureCopy.fullStatement.toLowerCase();
        expect(lower, isNot(contains('sqlite')));
        expect(lower, isNot(contains('exclusively')));
      });

      test('does not claim anything about training-data clauses', () {
        expect(
          OnDeviceArchitectureCopy.fullStatement.toLowerCase(),
          isNot(contains('training')),
        );
      });

      test('does not claim this device produces transcripts unconditionally',
          () {
        final lower = OnDeviceArchitectureCopy.architectureBody.toLowerCase();
        // The old wording ran storage and production together: "the audio you
        // record, the transcripts it becomes, and the reflections you read
        // stay here" reads as a claim that this device makes them.
        expect(lower, isNot(contains('the transcripts it becomes')));
        expect(lower, contains('stay in local databases'));
        expect(lower, contains('where the system supports it'));
        expect(lower, contains('on our servers when you allow that'));
      });
    });

    test('frames remote processing as a choice the user makes', () {
      final lower = OnDeviceArchitectureCopy.remoteCallout.toLowerCase();
      expect(lower, contains('unless you choose'));
      expect(lower, contains('turn it off'));
      expect(OnDeviceArchitectureCopy.remoteHeading, contains('opt-in'));
    });
  });
}
