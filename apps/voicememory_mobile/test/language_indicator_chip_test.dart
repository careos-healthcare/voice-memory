import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/language_model.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/widgets/language/language_indicator_chip.dart';

String _chipLabel(String code) =>
    '${localized('languageLabelPrefix', code)}: ${languageDisplayName(code)}';

void main() {
  testWidgets('non-English language chip appears', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LanguageIndicatorChip(
            languageCode: 'es',
            detectedCode: 'es',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text(_chipLabel('es')), findsOneWidget);
  });

  testWidgets('tapping the chip opens the language override sheet', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LanguageIndicatorChip(
            languageCode: 'gu',
            detectedCode: 'gu',
            onSelected: (code) => selected = code,
          ),
        ),
      ),
    );

    await tester.tap(find.text(_chipLabel('gu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(localized('reflectionLanguageTitle', 'gu')),
      findsOneWidget,
    );
    expect(find.text(localized('useDetectedLanguage', 'gu')), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 'en');
  });

  testWidgets('manual language override updates UI copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _LanguageHarness()));

    expect(find.text(localized('useThisTomorrow', 'es')), findsOneWidget);

    await tester.tap(find.text(_chipLabel('es')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(localized('useThisTomorrow', 'en')), findsOneWidget);
    expect(find.text(localized('useThisTomorrow', 'es')), findsNothing);
  });
}

class _LanguageHarness extends StatefulWidget {
  const _LanguageHarness();

  @override
  State<_LanguageHarness> createState() => _LanguageHarnessState();
}

class _LanguageHarnessState extends State<_LanguageHarness> {
  String _code = 'es';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(localized('useThisTomorrow', _code)),
          LanguageIndicatorChip(
            languageCode: _code,
            detectedCode: 'es',
            onSelected: (code) => setState(() => _code = code),
          ),
        ],
      ),
    );
  }
}
