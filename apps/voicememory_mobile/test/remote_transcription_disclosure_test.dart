import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  late Directory directory;
  late MobilePrefsStore prefs;
  late RemoteTranscriptionDisclosureStore disclosure;

  setUpAll(AppConfig.initApiResolution);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vm_disclosure_');
    prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
    disclosure = RemoteTranscriptionDisclosureStore(() => prefs);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'state stores purpose-specific version and revoke clears acceptance',
    () async {
      expect(
        (await disclosure.check()).status,
        RemoteTranscriptionDisclosureStatus.required,
      );

      await disclosure.acceptCurrent();
      final persisted = await prefs.readJsonMap(
        RemoteTranscriptionDisclosureStore.storageKey,
      );
      expect(persisted, {
        'scopes': {
          'guest': {
            'transcriptionAcceptedVersion':
                remoteTranscriptionDisclosureVersion,
          },
        },
      });
      expect(persisted.toString(), isNot(contains('audio')));
      expect(persisted.toString(), isNot(contains('copy')));
      expect((await disclosure.check()).isAccepted, isTrue);
      expect(
        (await disclosure.check(
          purpose: RemoteProcessingPurpose.interpretation,
        )).isAccepted,
        isFalse,
      );

      await disclosure.revoke();
      expect(
        await prefs.readJsonMap(RemoteTranscriptionDisclosureStore.storageKey),
        {'scopes': <String, dynamic>{}},
      );
      expect((await disclosure.check()).isAccepted, isFalse);
    },
  );

  test('disclosure acceptance is isolated across archive identities', () async {
    var archiveId = 'guest-archive';
    final scoped = RemoteTranscriptionDisclosureStore(
      () => prefs,
      archiveId: () => archiveId,
    );
    await scoped.acceptCurrent(purpose: RemoteProcessingPurpose.interpretation);
    expect(
      (await scoped.check(
        purpose: RemoteProcessingPurpose.interpretation,
      )).isAccepted,
      isTrue,
    );

    archiveId = 'account-alice';
    expect(
      (await scoped.check(
        purpose: RemoteProcessingPurpose.interpretation,
      )).isAccepted,
      isFalse,
    );
    await scoped.acceptCurrent(purpose: RemoteProcessingPurpose.transcription);

    archiveId = 'account-bob';
    expect((await scoped.check()).isAccepted, isFalse);
    expect(
      (await scoped.check(
        purpose: RemoteProcessingPurpose.interpretation,
      )).isAccepted,
      isFalse,
    );

    archiveId = 'guest-archive';
    expect((await scoped.check()).isAccepted, isFalse);
    expect(
      (await scoped.check(
        purpose: RemoteProcessingPurpose.interpretation,
      )).isAccepted,
      isTrue,
    );
  });

  test('older accepted version is not current', () async {
    await prefs.writeJsonMap(RemoteTranscriptionDisclosureStore.storageKey, {
      'acceptedVersion': '999',
    });
    expect(
      (await disclosure.check()).status,
      RemoteTranscriptionDisclosureStatus.required,
    );
  });

  test('network spy sees no transcribe request without acceptance', () async {
    var networkRequests = 0;
    final api = VoiceCaptureApiClient(
      ApiTransport(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async {
          networkRequests++;
          return http.Response('{}', 500);
        }),
      ),
      remoteTranscriptionDisclosure: disclosure,
    );
    final audio = File('${directory.path}/voice.m4a')
      ..writeAsBytesSync(const [1, 2, 3, 4]);

    await expectLater(
      api.postTranscribe(
        audioFile: audio,
        durationSeconds: 1,
        captureToken: 'token',
      ),
      throwsA(
        isA<RemoteDisclosureRequiredException>().having(
          (error) => error.code,
          'code',
          'remoteDisclosureRequired',
        ),
      ),
    );
    expect(networkRequests, 0);
  });

  test('accepted upload carries the exact disclosure version header', () async {
    await disclosure.acceptCurrent();
    final api = VoiceCaptureApiClient(
      ApiTransport(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          expect(
            request.headers[remoteTranscriptionDisclosureHeader],
            remoteTranscriptionDisclosureVersion,
          );
          return http.Response(
            jsonEncode({'transcript': 'Accepted transcript'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
      remoteTranscriptionDisclosure: disclosure,
    );
    final audio = File('${directory.path}/accepted.m4a')
      ..writeAsBytesSync(const [1, 2, 3, 4]);

    expect(
      await api.postTranscribe(
        audioFile: audio,
        durationSeconds: 1,
        captureToken: 'token',
      ),
      'Accepted transcript',
    );
  });
}
