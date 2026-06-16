import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/share/archive_share_actions.dart';
import 'package:voicememory_mobile/features/share/archive_share_text.dart';
import 'package:voicememory_mobile/features/trust/pro_trust_copy.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';

const MethodChannel _shareChannel = MethodChannel(
  'dev.fluttercommunity.plus/share',
);

void main() {
  const sampleText =
      'My archive noticed something.\n\nRecorded with ArchiveMe.';

  group('ArchiveShareText', () {
    test('normalizes whitespace', () {
      expect(ArchiveShareText.normalize('  hello  '), 'hello');
    });

    test('rejects empty share text', () {
      expect(ArchiveShareText.isShareable(''), isFalse);
      expect(ArchiveShareText.isShareable('   '), isFalse);
    });

    test('pro trust template includes ArchiveMe and no banned copy', () {
      expect(
        ArchiveShareText.includesArchiveMe(ProTrustCopy.shareTextTemplate),
        isTrue,
      );
      expect(
        ArchiveShareText.includesBannedConsumerCopy(
          ProTrustCopy.shareTextTemplate,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveShareActions', () {
    testWidgets('copy share text writes exact expected text to clipboard', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      late ArchiveShareOutcome outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  outcome = await ArchiveShareActions.copyShareText(
                    context,
                    text: sampleText,
                    showConfirmation: false,
                  );
                },
                child: const Text('copy'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pump();

      expect(outcome, ArchiveShareOutcome.copied);
      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((copyCall.arguments as Map)['text'], sampleText);
    });

    testWidgets('copy button shows confirmation snackbar', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ArchiveShareActions.copyShareText(
                  context,
                  text: sampleText,
                ),
                child: const Text('copy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(ArchiveShareActions.copyConfirmation), findsOneWidget);
    });

    testWidgets('share uses hook with non-empty text when provided', (
      tester,
    ) async {
      String? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                shared = sampleText;
              },
              child: const Text('noop'),
            ),
          ),
        ),
      );
      expect(shared, isNull);
      await tester.tap(find.text('noop'));
      await tester.pump();
      expect(shared, sampleText);
    });

    testWidgets('share fallback copies text when native share fails', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _shareChannel,
        (call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _shareChannel,
          null,
        );
      });

      ArchiveShareOutcome outcome = ArchiveShareOutcome.failed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  outcome = await ArchiveShareActions.shareShareText(
                    context,
                    text: sampleText,
                  );
                },
                child: const Text('share'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(outcome, ArchiveShareOutcome.fallbackCopied);
      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((copyCall.arguments as Map)['text'], sampleText);
      expect(
        find.text(ArchiveShareActions.shareFallbackMessage),
        findsOneWidget,
      );
    });

    testWidgets('empty share text returns emptyText outcome', (tester) async {
      late ArchiveShareOutcome outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                outcome = await ArchiveShareActions.copyShareText(
                  context,
                  text: '   ',
                  showConfirmation: false,
                );
              },
              child: const Text('copy'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pump();
      expect(outcome, ArchiveShareOutcome.emptyText);
    });

    testWidgets('sharePositionOrigin returns non-zero rect from context', (
      tester,
    ) async {
      Rect? origin;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              origin = ArchiveShareActions.sharePositionOrigin(context);
              return const SizedBox(width: 120, height: 40);
            },
          ),
        ),
      );
      await tester.pump();
      expect(origin, isNotNull);
      expect(origin!.width, greaterThan(0));
      expect(origin!.height, greaterThan(0));
    });

    test('trackShareAction emits only safe analytics properties', () {
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest((event, properties) {
        captured.add((event: event, props: properties));
      });
      addTearDown(ActivationFunnelAnalytics.resetForTest);

      ArchiveShareActions.trackShareAction(
        source: 'record',
        cardType: 'aha_proof_share',
        shareType: 'copy',
        status: 'copied',
        entryCount: 2,
        memoryScope: 'automatic',
      );

      expect(captured, hasLength(1));
      expect(
        captured.single.event,
        ActivationFunnelAnalytics.archiveShareAction,
      );
      expect(
        captured.single.props.keys.toList(),
        containsAll([
          'source',
          'card_type',
          'share_type',
          'status',
          'entry_count',
          'memory_scope',
        ]),
      );
      for (final value in captured.single.props.values) {
        expect(value.toString().contains('My archive'), isFalse);
      }
    });

    testWidgets(
      'share fallback does not throw if widget unmounts before snackbar',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _shareChannel,
          (call) async {
            throw PlatformException(code: 'UNAVAILABLE');
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _shareChannel,
            null,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: _UnmountAfterShareButton(text: sampleText)),
          ),
        );

        await tester.tap(find.text('share'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('share'), findsNothing);
      },
    );
  });
}

class _UnmountAfterShareButton extends StatefulWidget {
  const _UnmountAfterShareButton({required this.text});

  final String text;

  @override
  State<_UnmountAfterShareButton> createState() =>
      _UnmountAfterShareButtonState();
}

class _UnmountAfterShareButtonState extends State<_UnmountAfterShareButton> {
  var _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return ElevatedButton(
      onPressed: () async {
        await ArchiveShareActions.shareShareText(context, text: widget.text);
        if (mounted) setState(() => _visible = false);
      },
      child: const Text('share'),
    );
  }
}
