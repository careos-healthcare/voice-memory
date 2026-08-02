import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure_dialog.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

void main() {
  // This dialog persists the user's answer before it closes, so the test hung
  // forever and --timeout could not interrupt it. Two separate reasons, both
  // fixed by building the store here rather than from a file.
  //
  // A testWidgets body runs against a fake clock, which cannot advance a real
  // dart:io future. So the file-backed write never completed, the dialog never
  // closed, and pumpAndSettle spun on the button's progress indicator.
  //
  // In-memory secure storage keeps reads and writes off the filesystem. That
  // alone is not enough: writes are serialised through a mutex seeded in the
  // store's constructor, and a Future scheduled in the real zone stays on the
  // real microtask queue, which the fake clock never drains. Reads bypass the
  // mutex, which is why only writes stalled. Constructing the store inside the
  // test body puts that mutex in the fake zone, where pump drains it.
  RemoteTranscriptionDisclosureStore newStore() {
    final prefs = MobilePrefsStore(
      // Never read or written: secure storage serves every access, and only
      // MobilePrefsStore.open consults the legacy plaintext file.
      file: File('${Directory.systemTemp.path}/unused_disclosure_prefs.json'),
      secureStorage: InMemorySecureStorageService(),
    );
    return RemoteTranscriptionDisclosureStore(() => prefs);
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'dialog is accessible in ${brightness.name} mode with large text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final store = newStore();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(2),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => showRemoteTranscriptionDisclosure(
                      context: context,
                      store: store,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          find.text(RemoteTranscriptionDisclosureCopy.title),
          findsOneWidget,
        );
        for (final label in const [
          RemoteTranscriptionDisclosureCopy.continueOnline,
          RemoteTranscriptionDisclosureCopy.notNow,
          RemoteTranscriptionDisclosureCopy.typeInstead,
          RemoteTranscriptionDisclosureCopy.learnMoreAction,
        ]) {
          expect(find.text(label), findsOneWidget);
          expect(tester.getSemantics(find.text(label)).label, contains(label));
        }
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.text(RemoteTranscriptionDisclosureCopy.learnMoreAction),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(RemoteTranscriptionDisclosureCopy.learnMore),
          findsOneWidget,
        );
        await tester.tap(find.text(RemoteTranscriptionDisclosureCopy.notNow));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('remote_transcription_disclosure_dialog')),
          findsNothing,
        );
        // Disposed here, not in a teardown: the framework asserts no handle is
        // live at the end of the body, which runs before teardowns.
        semantics.dispose();
      },
    );
  }

  testWidgets('continue persists acceptance before closing', (tester) async {
    final store = newStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showRemoteTranscriptionDisclosure(
              context: context,
              store: store,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(RemoteTranscriptionDisclosureCopy.continueOnline),
    );
    await tester.pumpAndSettle();

    expect(
      (await store.read()).isCurrentFor(RemoteProcessingPurpose.transcription),
      isTrue,
    );
    expect(
      find.byKey(const Key('remote_transcription_disclosure_dialog')),
      findsNothing,
    );
  });

  testWidgets('Type instead returns a distinct non-consent action', (
    tester,
  ) async {
    final store = newStore();
    RemoteTranscriptionDisclosureAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selected = await showRemoteTranscriptionDisclosure(
                context: context,
                store: store,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RemoteTranscriptionDisclosureCopy.typeInstead));
    await tester.pumpAndSettle();

    expect(selected, RemoteTranscriptionDisclosureAction.typeInstead);
    expect(
      (await store.read()).isCurrentFor(RemoteProcessingPurpose.transcription),
      isFalse,
    );
  });

  testWidgets('interpretation disclosure does not offer Type instead', (
    tester,
  ) async {
    final store = newStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showRemoteTranscriptionDisclosure(
              context: context,
              store: store,
              purpose: RemoteProcessingPurpose.interpretation,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Online interpretation'), findsOneWidget);
    expect(
      find.text(RemoteTranscriptionDisclosureCopy.typeInstead),
      findsNothing,
    );
    await tester.tap(find.text(RemoteTranscriptionDisclosureCopy.notNow));
    await tester.pumpAndSettle();
  });
}
