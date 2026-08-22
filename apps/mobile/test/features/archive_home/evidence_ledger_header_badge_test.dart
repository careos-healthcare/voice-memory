import 'package:archiveme_mobile/features/archive_home/evidence_ledger_copy.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_count_controller.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_header_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(EvidenceLedgerCountController.instance.resetForTest);

  testWidgets('EvidenceLedgerHeaderBadge renders count label', (tester) async {
    EvidenceLedgerCountController.instance.resetForTest();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              EvidenceLedgerHeaderBadge(compact: true),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('evidence_ledger_header_badge')), findsOneWidget);
    expect(
      find.text(
        EvidenceLedgerCopy.badgeLabel(citableFactCount: 0, entryCount: 0),
      ),
      findsOneWidget,
    );
  });
}