import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_consent_adapter.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_contact_store.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage_sandbox.dart';

class _FakeVerificationService implements ConsentVerificationService {
  _FakeVerificationService.succeeds(this._token) : _error = null;
  _FakeVerificationService.fails(String message)
      : _token = null,
        _error = message;

  final MonitoringConsentToken? _token;
  final String? _error;

  @override
  Future<MonitoringConsentToken> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
  }) async {
    final error = _error;
    if (error != null) throw StateError(error);
    return _token!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _RecordingMultiPartyAccessService implements MultiPartyAccessService {
  final List<Map<String, Object?>> calls = [];

  @override
  Future<void> recordIssuedGrant({
    required MultiPartyAccessRole role,
    required String partyId,
    required String tokenId,
    required DateTime issuedAt,
    required DateTime expiresAt,
  }) async {
    calls.add({
      'role': role,
      'partyId': partyId,
      'tokenId': tokenId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

void main() {
  late TestStorageSandbox sandbox;

  setUpAll(() {
    // AppServices.resetForTest starts ConnectivityAwareNetworkSource, which
    // throws MissingPluginException without this stub.
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });
  });

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  final issuedAt = DateTime.utc(2026, 1, 1);
  final expiresAt = DateTime.utc(2026, 1, 8);
  const contact = CaregiverGrantContact(name: 'Sam', email: 'sam@example.com');
  final request = CaregiverGrantRequest(
    caregiverId: 'caregiver-1',
    contact: contact,
  );

  test('a successful issue records the grant with the right values', () async {
    final token = MonitoringConsentToken(
      tokenId: 'token-1',
      subjectAccountId: 'user-1',
      caregiverId: 'caregiver-1',
      permissions: CaregiverPermissions.defaultScopes,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      policyVersion: 1,
      signature: 'sig',
    );
    final recorder = _RecordingMultiPartyAccessService();
    final adapter = CaregiverGrantConsentAdapter(
      verificationService: _FakeVerificationService.succeeds(token),
      contactStore: await CaregiverGrantContactStore.open(),
      multiPartyAccessService: recorder,
    );

    final outcome = await adapter.issue(request);

    expect(outcome, isA<CaregiverGrantGranted>());
    expect(recorder.calls, hasLength(1));
    expect(recorder.calls.single['role'], MultiPartyAccessRole.caregiver);
    expect(recorder.calls.single['partyId'], 'Sam');
    expect(recorder.calls.single['tokenId'], 'token-1');
    expect(recorder.calls.single['issuedAt'], issuedAt);
    expect(recorder.calls.single['expiresAt'], expiresAt);
  });

  test('a failed issue never records a grant', () async {
    final recorder = _RecordingMultiPartyAccessService();
    final adapter = CaregiverGrantConsentAdapter(
      verificationService:
          _FakeVerificationService.fails('backend not configured'),
      contactStore: await CaregiverGrantContactStore.open(),
      multiPartyAccessService: recorder,
    );

    final outcome = await adapter.issue(request);

    expect(outcome, isA<CaregiverGrantFailed>());
    expect(recorder.calls, isEmpty);
  });
}
