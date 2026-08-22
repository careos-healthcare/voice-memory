import 'dart:io';

import 'package:archiveme_mobile/app.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'check') {
        return ['wifi'];
      }
      return null;
    });
  });

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('vm_test_');
    await AppServices.resetForTest(journalPath: '${dir.path}/journal.json');
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
    onboardingGate.resetSessionRedirectsForTest();
  });

  testWidgets('ArchiveMeApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArchiveMeApp());
    await tester.pump();

    expect(find.byType(ArchiveMeApp), findsOneWidget);
  });

  test('archive home redirect applies once per session', () {
    onboardingGate.resetSessionRedirectsForTest();
    expect(onboardingGate.archiveHomeRedirectApplied, isFalse);
    onboardingGate.markArchiveHomeRedirectApplied();
    expect(onboardingGate.archiveHomeRedirectApplied, isTrue);
  });

  test('PremiumEntitlements parses pro tier', () {
    final e = PremiumEntitlements.fromJson({
      'tier': 'pro',
      'entitlements': ['unlimited_archive'],
      'billingConnected': true,
      'source': 'server',
    });
    expect(e.isPro, isTrue);
  });

  test('JournalEntry round-trip json', () {
    final entry = JournalEntry(
      id: 'e1',
      createdAt: DateTime.parse('2026-01-01T12:00:00Z'),
      transcript: 'Hello',
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'tired',
        emotionalIntensity: 3,
        recurringThemes: ['work'],
        exactLanguagePattern: 'I am done',
        concreteObservation: 'You sound finished for today.',
        repeatedSignal: 'Nothing repeated clearly.',
      ),
      biomarkers: const CognitiveBiomarkers(
        lexicalDiversity: 0.55,
        cohesionDrift: 0.12,
        emotionalVolatility: 0.33,
      ),
    );
    final parsed = JournalEntry.fromJson(entry.toJson());
    expect(parsed.id, 'e1');
    expect(parsed.transcript, 'Hello');
    expect(parsed.reflection.concreteObservation, contains('finished'));
    expect(parsed.biomarkers, entry.biomarkers);
  });

  test('SecureStorage rejects sensitive keys', () {
    final storage = SecureStorageService();
    expect(
      () => storage.write('stripe_secret', 'x'),
      throwsA(isA<StateError>()),
    );
  });
}