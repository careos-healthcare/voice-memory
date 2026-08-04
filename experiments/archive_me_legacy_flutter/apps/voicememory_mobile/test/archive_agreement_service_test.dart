import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_agreement/archive_agreement_models.dart';
import 'package:voicememory_mobile/features/archive_agreement/archive_agreement_service.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;
  late ArchiveAgreementService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive_agreement_test');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    service = ArchiveAgreementService.fromPrefs(prefs);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('record agree persists and surfaces as latest', () async {
    const statement = 'You tend to avoid difficult conversations at work.';
    await service.record(
      theoryStatement: statement,
      response: ArchiveTheoryAgreementResponse.agree,
      confidencePercent: 72,
    );

    final latest = await service.latestResponseForTheory(statement);
    expect(latest, ArchiveTheoryAgreementResponse.agree);

    final view = await service.historyForTheory(
      currentTheoryStatement: statement,
    );
    expect(view.records, hasLength(1));
    expect(view.records.first.response, ArchiveTheoryAgreementResponse.agree);
    expect(view.records.first.confidencePercent, 72);
    expect(
      view.latestForCurrentTheory?.response,
      ArchiveTheoryAgreementResponse.agree,
    );
  });

  test('each tap appends history newest first', () async {
    const statement = 'You prioritize calm over confrontation.';
    await service.record(
      theoryStatement: statement,
      response: ArchiveTheoryAgreementResponse.agree,
    );
    await service.record(
      theoryStatement: statement,
      response: ArchiveTheoryAgreementResponse.unsure,
    );
    await service.record(
      theoryStatement: statement,
      response: ArchiveTheoryAgreementResponse.disagree,
    );

    final view = await service.historyForTheory(
      currentTheoryStatement: statement,
    );
    expect(view.records, hasLength(3));
    expect(view.records[0].response, ArchiveTheoryAgreementResponse.disagree);
    expect(view.records[1].response, ArchiveTheoryAgreementResponse.unsure);
    expect(view.records[2].response, ArchiveTheoryAgreementResponse.agree);
    expect(
      view.latestForCurrentTheory?.response,
      ArchiveTheoryAgreementResponse.disagree,
    );
  });

  test('theory key matches despite whitespace casing', () async {
    await service.record(
      theoryStatement: '  You   avoid   conflict  ',
      response: ArchiveTheoryAgreementResponse.unsure,
    );

    final latest = await service.latestResponseForTheory('you avoid conflict');
    expect(latest, ArchiveTheoryAgreementResponse.unsure);
  });

  test('distinct theories keep separate latest responses', () async {
    await service.record(
      theoryStatement: 'Theory A',
      response: ArchiveTheoryAgreementResponse.agree,
    );
    await service.record(
      theoryStatement: 'Theory B',
      response: ArchiveTheoryAgreementResponse.disagree,
    );

    expect(
      await service.latestResponseForTheory('Theory A'),
      ArchiveTheoryAgreementResponse.agree,
    );
    expect(
      await service.latestResponseForTheory('Theory B'),
      ArchiveTheoryAgreementResponse.disagree,
    );
    final view = await service.historyForTheory(
      currentTheoryStatement: 'Theory A',
    );
    expect(view.records, hasLength(2));
  });

  test('store round-trip via json', () async {
    await service.record(
      theoryStatement: 'Round trip theory',
      response: ArchiveTheoryAgreementResponse.unsure,
    );
    final reloaded = ArchiveAgreementService.fromPrefs(prefs);
    final view = await reloaded.historyForTheory(
      currentTheoryStatement: 'Round trip theory',
    );
    expect(view.records, hasLength(1));
    expect(view.records.first.theoryStatement, 'Round trip theory');
    expect(view.records.first.response, ArchiveTheoryAgreementResponse.unsure);
  });
}
