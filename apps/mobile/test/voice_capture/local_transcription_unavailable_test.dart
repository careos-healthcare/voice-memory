import 'dart:io';

import 'package:archiveme_mobile/features/capture_flow/ui/local_transcription_unavailable_card.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_choice_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_unavailable_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubIosProbe implements IosOnDeviceRecognitionProbe {
  _StubIosProbe(this._answer);
  _StubIosProbe.throwing() : _answer = null;

  final bool? _answer;
  final askedFor = <String>[];

  int get calls => askedFor.length;

  @override
  Future<bool> supportsOnDeviceRecognition(ConfirmedSpeechLocale locale) async {
    askedFor.add(locale.identifier);
    final answer = _answer;
    if (answer == null) throw StateError('probe channel missing');
    return answer;
  }
}

SpeechLocaleReader _confirmed(String? identifier) =>
    () async => ConfirmedSpeechLocale.confirmed(identifier);

Future<Never> _unreadableLocale() async => throw StateError('prefs unreadable');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    NativeSpeechTranscription.debugPlatformOverride = null;
  });

  group('availability is measured, not assumed', () {
    test('Android reports no local recogniser this app can drive', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'android';

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed('en-GB'),
      ).check();

      expect(support.isAvailable, isFalse);
      expect(
        support.reason,
        LocalTranscriptionUnavailableReason.platformUnsupported,
      );
    });

    test('iOS without a confirmed language is not available', () async {
      // The previous version of this class took no locale at all and answered
      // "available" here, so `TranscriptionCapabilityPolicy` stayed quiet while
      // no recording on the device could produce a transcript.
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      final probe = _StubIosProbe(true);

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed(null),
        iosProbe: probe,
      ).check();

      expect(support.isAvailable, isFalse);
      expect(
        support.reason,
        LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
      );
      expect(
        probe.calls,
        0,
        reason: 'there is no language to ask the recogniser about',
      );
    });

    test('an unreadable language preference is not a language', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _unreadableLocale,
        iosProbe: _StubIosProbe(true),
      ).check();

      expect(
        support.reason,
        LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
      );
    });

    test('iOS with a probe that says no reports a locale gap', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      final probe = _StubIosProbe(false);

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed('gu-IN'),
        iosProbe: probe,
      ).check();

      expect(probe.askedFor, ['gu-IN']);
      expect(support.isAvailable, isFalse);
      expect(
        support.reason,
        LocalTranscriptionUnavailableReason.localeUnsupported,
      );
    });

    test('iOS with a probe that says yes stays available', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed('en-GB'),
        iosProbe: _StubIosProbe(true),
      ).check();

      expect(support.isAvailable, isTrue);
    });

    test('a probe that throws does not manufacture a capability gap', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed('en-GB'),
        iosProbe: _StubIosProbe.throwing(),
      ).check();

      // A broken probe is not evidence. Reading it as "unavailable" would put a
      // prompt in front of someone whose device works and push them toward
      // uploading audio to answer it. This is also the state of today's iOS
      // build, whose Swift handler has no `supportsOnDeviceRecognition` case.
      expect(support.isAvailable, isTrue);
    });

    test('Android is unavailable regardless of the probe', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'android';
      final probe = _StubIosProbe(true);

      final support = await PlatformLocalTranscriptionAvailability(
        confirmedLocale: _confirmed('en-GB'),
        iosProbe: probe,
      ).check();

      expect(support.isAvailable, isFalse);
      expect(probe.calls, 0, reason: 'the platform answer settles it');
    });
  });

  group('the policy asks only on a real capability gap', () {
    TranscriptionCapabilityOutcome decide({
      required bool localAvailable,
      required bool remotePermitted,
      LocalTranscriptionChoice choice = LocalTranscriptionChoice.unset,
      LocalTranscriptionUnavailableReason reason =
          LocalTranscriptionUnavailableReason.platformUnsupported,
    }) {
      return TranscriptionCapabilityPolicy.decide(
        localSupport: localAvailable
            ? const LocalTranscriptionSupport.available()
            : LocalTranscriptionSupport.unavailable(reason),
        remoteTranscriptionPermitted: remotePermitted,
        recordedChoice: choice,
      );
    }

    test('an unconfirmed language asks for a language, not for an upload', () {
      // Two different questions. Offering "send it to a server" as the answer
      // to "which language do you speak" turns a settings choice into a
      // privacy decision the customer did not ask to make.
      expect(
        decide(
          localAvailable: false,
          remotePermitted: false,
          reason:
              LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
        ),
        TranscriptionCapabilityOutcome.askSpeechLanguage,
      );
    });

    test('an unconfirmed language with remote permitted stays quiet', () {
      expect(
        decide(
          localAvailable: false,
          remotePermitted: true,
          reason:
              LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
        ),
        TranscriptionCapabilityOutcome.proceed,
      );
    });

    test('a standing "save without text" outranks the language question', () {
      expect(
        decide(
          localAvailable: false,
          remotePermitted: false,
          choice: LocalTranscriptionChoice.noTranscription,
          reason:
              LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed,
        ),
        TranscriptionCapabilityOutcome.respectNoTranscription,
      );
    });

    test('local works: say nothing, whatever remote is', () {
      expect(
        decide(localAvailable: true, remotePermitted: false),
        TranscriptionCapabilityOutcome.proceed,
      );
      expect(
        decide(localAvailable: true, remotePermitted: true),
        TranscriptionCapabilityOutcome.proceed,
      );
    });

    test('local missing but remote permitted: say nothing', () {
      expect(
        decide(localAvailable: false, remotePermitted: true),
        TranscriptionCapabilityOutcome.proceed,
      );
    });

    test('local missing, remote not permitted, unasked: ask', () {
      expect(
        decide(localAvailable: false, remotePermitted: false),
        TranscriptionCapabilityOutcome.askOnce,
      );
    });

    test('a recorded "no transcription" is respected, not re-asked', () {
      expect(
        decide(
          localAvailable: false,
          remotePermitted: false,
          choice: LocalTranscriptionChoice.noTranscription,
        ),
        TranscriptionCapabilityOutcome.respectNoTranscription,
      );
    });

    test('a recorded "transcribe it" that did not take is asked again', () {
      expect(
        decide(
          localAvailable: false,
          remotePermitted: false,
          choice: LocalTranscriptionChoice.remoteTranscription,
        ),
        TranscriptionCapabilityOutcome.askOnce,
      );
    });

    test('the decision has no input a network failure could move', () {
      // The whole separation between a capability gap and a flaky connection is
      // structural: the three inputs are a device capability, a permission, and
      // a stored answer. A timeout, a 500, or an offline error is none of them,
      // so no request outcome can reach this function to raise a prompt.
      for (final localAvailable in [true, false]) {
        for (final remotePermitted in [true, false]) {
          for (final choice in LocalTranscriptionChoice.values) {
            for (final reason
                in LocalTranscriptionUnavailableReason.values) {
              final first = decide(
                localAvailable: localAvailable,
                remotePermitted: remotePermitted,
                choice: choice,
                reason: reason,
              );
              final second = decide(
                localAvailable: localAvailable,
                remotePermitted: remotePermitted,
                choice: choice,
                reason: reason,
              );
              expect(
                first,
                second,
                reason: 'pure for $localAvailable/$choice/$reason',
              );
            }
          }
        }
      }
    });
  });

  group('the answer is stored once and honoured', () {
    late Directory dir;
    late LocalTranscriptionChoiceStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vm_local_stt_choice_');
      store = LocalTranscriptionChoiceStore(
        await MobilePrefsStore.open('${dir.path}/prefs.json'),
      );
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('unasked reads as unset', () async {
      expect(await store.read(), LocalTranscriptionChoice.unset);
    });

    test('both answers round-trip', () async {
      await store.record(LocalTranscriptionChoice.noTranscription);
      expect(await store.read(), LocalTranscriptionChoice.noTranscription);

      await store.record(LocalTranscriptionChoice.remoteTranscription);
      expect(await store.read(), LocalTranscriptionChoice.remoteTranscription);
    });

    test('recording "unset" is not a way to erase an answer', () async {
      await store.record(LocalTranscriptionChoice.noTranscription);
      await store.record(LocalTranscriptionChoice.unset);
      expect(await store.read(), LocalTranscriptionChoice.noTranscription);
    });

    test('an unreadable store reads as unasked, not as consent', () async {
      // A directory where the prefs file should be: every read throws. Reading
      // a storage error as `remoteTranscription` would upload on a bad disk.
      final failing = LocalTranscriptionChoiceStore(
        MobilePrefsStore(file: File(dir.path)),
      );
      expect(await failing.read(), LocalTranscriptionChoice.unset);
    });
  });

  group('the prompt names the processor', () {
    test('remote detail names OpenAI and whisper-1 and not Anthropic', () {
      const detail = LocalTranscriptionUnavailableCopy.remoteDetail;
      expect(detail, contains('OpenAI'));
      expect(detail, contains('whisper-1'));

      for (final text in [
        LocalTranscriptionUnavailableCopy.title,
        LocalTranscriptionUnavailableCopy.body,
        LocalTranscriptionUnavailableCopy.remoteCta,
        detail,
        LocalTranscriptionUnavailableCopy.declineCta,
        LocalTranscriptionUnavailableCopy.declineDetail,
        LocalTranscriptionUnavailableCopy.footnote,
      ]) {
        expect(text, isNot(contains('Anthropic')));
        for (final absolute in [
          '100%',
          'zero',
          'entirely',
          'always',
          'never',
          'only ever',
        ]) {
          expect(
            text.toLowerCase(),
            isNot(contains(absolute)),
            reason: 'absolute "$absolute" in: $text',
          );
        }
      }
    });

    test('declining is described as a save, not a loss of the recording', () {
      expect(
        LocalTranscriptionUnavailableCopy.declineDetail,
        contains('audio'),
      );
      expect(
        LocalTranscriptionUnavailableCopy.footnote,
        contains('once'),
        reason: 'the prompt promises it asks once; the store has to keep that',
      );
    });
  });

  group('the card offers two real answers', () {
    testWidgets('both buttons report a choice and neither is a dismissal',
        (tester) async {
      final choices = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalTranscriptionUnavailableCard(
              onChoice: choices.add,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('local_transcription_unavailable_card')),
        findsOneWidget,
      );
      expect(find.text(LocalTranscriptionUnavailableCopy.remoteDetail),
          findsOneWidget);

      await tester.tap(
        find.byKey(const Key('local_transcription_choose_remote')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('local_transcription_choose_none')),
      );
      await tester.pump();

      expect(choices, [true, false]);
      expect(
        find.byType(IconButton),
        findsNothing,
        reason: 'no close affordance: there is no third answer',
      );
    });

    test('the card widget makes no network call available to it', () {
      // Cheap structural check on the surface the card is given: a
      // ValueChanged<bool> and a bool. Nothing it can reach uploads anything.
      const card = LocalTranscriptionUnavailableCard(onChoice: _ignore);
      expect(card.submitting, isFalse);
    });
  });
}

void _ignore(bool _) {}
