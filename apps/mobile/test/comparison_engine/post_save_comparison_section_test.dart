import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/pattern_evidence_view_state.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/post_save_comparison_section.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubController extends PostSaveComparisonController {
  _StubController(PostSaveComparisonUiState initialState)
    : _initialState = initialState,
      super(apiClient: _NoOpApiClient(), prefs: _NoOpPrefs());

  final PostSaveComparisonUiState _initialState;

  @override
  PostSaveComparisonUiState get uiState => _initialState;
}

class _NoOpApiClient implements ModelApiClient {
  @override
  Future<String> evaluatePrompts({
    required String systemPrompt,
    required String userPrompt,
  }) async => '';
}

class _NoOpPrefs implements PreferenceStore {
  @override
  bool getHasDismissedProPrompt() => false;

  @override
  Future<void> setHasDismissedProPrompt(bool value) async {}
}

void main() {
  group('postSaveComparisonHasVisibleEvidence', () {
    test('hides not enough evidence state', () {
      expect(
        postSaveComparisonHasVisibleEvidence(
          const PatternEvidenceViewState(
            state: PatternState.notEnoughEvidence,
            connectionText: 'A repeating thread may be forming.',
            pastQuote: 'past words',
            currentQuote: 'current words',
            whatChangedText: 'ArchiveMe needs more moments to be sure.',
            showProTrailPrompt: false,
          ),
        ),
        isFalse,
      );
    });

    test('requires both quotes for visible evidence', () {
      expect(
        postSaveComparisonHasVisibleEvidence(
          const PatternEvidenceViewState(
            state: PatternState.possibleRepeat,
            connectionText: 'This may connect.',
            pastQuote: '',
            currentQuote: 'current words',
            whatChangedText: 'Still forming.',
            showProTrailPrompt: false,
          ),
        ),
        isFalse,
      );
    });
  });

  group('PostSaveComparisonSection', () {
    testWidgets('shows loading shell while comparison runs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveComparisonSection(
              controller: _StubController(const ComparisonLoading()),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('comparison_loading')), findsOneWidget);
      expect(find.text('Archive Comparison'), findsNothing);
    });

    testWidgets('renders evidence card for meaningful text states', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveComparisonSection(
              controller: _StubController(
                const ComparisonSuccess(
                  PatternEvidenceViewState(
                    state: PatternState.possibleRepeat,
                    connectionText: 'This may connect to saying yes again.',
                    pastQuote: 'said yes before checking',
                    currentQuote: 'said yes again at work',
                    whatChangedText: 'It showed up around work again.',
                    showProTrailPrompt: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archive Comparison'), findsOneWidget);
      expect(find.text('Possible Repeat'), findsOneWidget);
    });

    testWidgets('collapses cleanly for not enough evidence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveComparisonSection(
              controller: _StubController(
                const ComparisonSuccess(
                  PatternEvidenceViewState(
                    state: PatternState.notEnoughEvidence,
                    connectionText: 'A repeating thread may be forming.',
                    pastQuote: 'past words',
                    currentQuote: 'current words',
                    whatChangedText: 'ArchiveMe needs more moments to be sure.',
                    showProTrailPrompt: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archive Comparison'), findsNothing);
      expect(find.byKey(const ValueKey('comparison_empty')), findsOneWidget);
    });

    testWidgets('transitions from loading shell to success content', (
      tester,
    ) async {
      PostSaveComparisonUiState phase = const ComparisonLoading();
      final hostKey = GlobalKey<_TransitionHarnessState>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: _TransitionHarness(
              key: hostKey,
              phase: phase,
              onPhaseChanged: (next) => phase = next,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('comparison_loading')), findsOneWidget);

      hostKey.currentState!.showSuccess();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));

      expect(find.byKey(const ValueKey('comparison_loading')), findsNothing);
      expect(find.text('Archive Comparison'), findsOneWidget);
    });
  });
}

class _TransitionHarness extends StatefulWidget {
  const _TransitionHarness({
    required this.phase, required this.onPhaseChanged, super.key,
  });

  final PostSaveComparisonUiState phase;
  final ValueChanged<PostSaveComparisonUiState> onPhaseChanged;

  @override
  State<_TransitionHarness> createState() => _TransitionHarnessState();
}

class _TransitionHarnessState extends State<_TransitionHarness> {
  late PostSaveComparisonUiState _phase;

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
  }

  void showSuccess() {
    setState(() {
      _phase = const ComparisonSuccess(
        PatternEvidenceViewState(
          state: PatternState.possibleRepeat,
          connectionText: 'This may connect to saying yes again.',
          pastQuote: 'said yes before checking',
          currentQuote: 'said yes again at work',
          whatChangedText: 'It showed up around work again.',
          showProTrailPrompt: false,
        ),
      );
    });
    widget.onPhaseChanged(_phase);
  }

  @override
  Widget build(BuildContext context) {
    return PostSaveComparisonSection(controller: _StubController(_phase));
  }
}