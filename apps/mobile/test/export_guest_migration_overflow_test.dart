import 'dart:io';

import 'package:archiveme_mobile/features/account_migration/account_data_migration_coordinator.dart';
import 'package:archiveme_mobile/features/account_migration/guest_data_migration_screen.dart';
import 'package:archiveme_mobile/screens/export_screen.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _smallScreen = Size(360, 640);

void main() {
  testWidgets('ExportScreen remains usable at 200% text scale', (tester) async {
    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      flutterErrors.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ExportScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const Key('export_and_share_button')), findsOneWidget);
    expect(
      flutterErrors,
      isEmpty,
      reason:
          'ExportScreen overflowed at 200% text scale: '
          '${flutterErrors.map((d) => d.exceptionAsString()).join('; ')}',
    );
    expect(tester.takeException(), isNull);
  });

  // Guest's _load() calls forActiveAccount() → JournalStore.open (real
  // filesystem). Widget tests use a fake async clock, so that Future never
  // completes unless runAsync. _loading stays true, CircularProgressIndicator
  // never settles, pumpAndSettle hits the 10-minute TimeoutException.
  // Inject an unopened coordinator (no open(), no AppServices) and pump()
  // once — same shape as ExportScreen above. Do not "fix" the heavy harness.
  testWidgets(
    'GuestDataMigrationScreen remains usable at 200% text scale',
    (tester) async {
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      final dir = Directory.systemTemp.createTempSync('guest_overflow_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final coordinator = AccountDataMigrationCoordinator(
        guestJournalStore: JournalStore(file: File('${dir.path}/g.json')),
        activeJournalStore: JournalStore(file: File('${dir.path}/a.json')),
        activePrefs: MobilePrefsStore(file: File('${dir.path}/p.json')),
        activeNamespace: AccountNamespace.forUserId('overflow'),
      );

      await tester.binding.setSurfaceSize(_smallScreen);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: GuestDataMigrationScreen(coordinator: coordinator),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(const Key('guest_migration_move')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        flutterErrors,
        isEmpty,
        reason:
            'GuestDataMigrationScreen overflowed at 200% text scale: '
            '${flutterErrors.map((d) => d.exceptionAsString()).join('; ')}',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
