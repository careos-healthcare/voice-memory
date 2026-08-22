import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capture_entry_actions.dart';
import 'package:archiveme_mobile/widgets/record/start_here_loader.dart';
import 'package:flutter/material.dart';

/// Canonical copy for Search tab when there are no recordings.
///
/// Every promise here is scoped to what search actually runs: FTS5 BM25 over
/// the transcript, tokenised `porter unicode61`. That stems inflections, so a
/// query for "confidence" also finds "confident", but it matches words rather
/// than meanings — it cannot reach a paraphrase that shares no word with the
/// query.
///
/// Two earlier bullets, "beliefs you've repeated" and "patterns that appear
/// over time", are deliberately absent. Both need semantic similarity, and
/// `SemanticVectorFusion.enabled` is off: with no encoder asset in the tree
/// every embedding resolves to `LocalReflectionEmbeddingInference`, a random
/// projection over word-position hashes that supports exact-duplicate matching
/// and nothing else. `HybridSearchEngine.search` therefore returns BM25 order
/// untouched for any query carrying both legs. Recurrence and pattern
/// surfacing are not switched on to be promised.
abstract class SearchEmptyCopy {
  SearchEmptyCopy._();

  static const String title = 'Nothing to search yet';
  static const String body =
      'As you record thoughts, your archive becomes searchable.';
  static const String searchableForHeader = "You'll be able to search for:";

  /// Four claims BM25 over the transcript genuinely delivers: the wording
  /// itself, a topic under the name the customer gave it, a named person or
  /// place, and complete recall of a term across the archive.
  static const List<String> searchableBullets = [
    'the words and phrases you actually said',
    "topics you've talked about",
    'people, places, and events',
    'every recording where a word came up',
  ];

  /// Framed as the customer's own words rather than as themes, because a term
  /// only matches where they said it. The pay-off is recall, not analysis.
  static const String futureSearchHeader =
      'Months from now, search the words you used:';
  static const List<String> exampleSearchTerms = [
    'confidence',
    'burnout',
    'starting a business',
    "I'm not ready",
  ];
  static const String exampleSupporting =
      'and find every recording where you said them.';
  static const String closing =
      'Record your first thought to begin building a searchable archive.';
}

const double kSearchEmptyMaxWidth = 400;
const double kSearchEmptyExamplesMaxWidth = 360;

/// Search-specific first-time empty state — not the archive empty experience.
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key, this.onRecord});

  final VoidCallback? onRecord;

  static String get semanticsLabel => [
    SearchEmptyCopy.title,
    SearchEmptyCopy.body,
    SearchEmptyCopy.searchableForHeader,
    ...SearchEmptyCopy.searchableBullets,
    SearchEmptyCopy.futureSearchHeader,
    ...SearchEmptyCopy.exampleSearchTerms,
    SearchEmptyCopy.exampleSupporting,
    SearchEmptyCopy.closing,
  ].join(' ');

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppTheme.foreground,
      height: 1.3,
    );
    const bodyStyle = TextStyle(
      color: AppTheme.muted,
      height: 1.45,
      fontSize: 15,
    );
    const sectionStyle = TextStyle(
      color: AppTheme.muted,
      height: 1.45,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    const bulletStyle = TextStyle(
      color: AppTheme.muted,
      height: 1.45,
      fontSize: 14,
    );
    const exampleStyle = TextStyle(
      color: AppTheme.muted,
      height: 1.5,
      fontSize: 14,
    );

    Widget bodyText(String text, {TextStyle style = bodyStyle}) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }

    Widget exampleTermsBlock() {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kSearchEmptyExamplesMaxWidth,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.muted.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var i = 0;
                  i < SearchEmptyCopy.exampleSearchTerms.length;
                  i++
                )
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < SearchEmptyCopy.exampleSearchTerms.length - 1
                          ? 8
                          : 0,
                    ),
                    child: Text(
                      '"${SearchEmptyCopy.exampleSearchTerms[i]}"',
                      style: exampleStyle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final content = Semantics(
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSearchEmptyMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_outlined,
              size: 56,
              color: AppTheme.muted.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 20),
            bodyText(SearchEmptyCopy.title, style: titleStyle),
            const SizedBox(height: 12),
            bodyText(SearchEmptyCopy.body),
            const SizedBox(height: 16),
            bodyText(SearchEmptyCopy.searchableForHeader, style: sectionStyle),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kSearchEmptyExamplesMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final bullet in SearchEmptyCopy.searchableBullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: bulletStyle),
                            Expanded(child: Text(bullet, style: bulletStyle)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            bodyText(SearchEmptyCopy.futureSearchHeader, style: sectionStyle),
            const SizedBox(height: 10),
            exampleTermsBlock(),
            const SizedBox(height: 10),
            bodyText(SearchEmptyCopy.exampleSupporting),
            const SizedBox(height: 12),
            bodyText(SearchEmptyCopy.closing),
            const SizedBox(height: 20),
            const StartHereLoader(surface: 'search_empty'),
            const SizedBox(height: 16),
            CaptureEntryActions(
              onRecord: onRecord ?? () => goToFirstRecording(context),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final minH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : _defaultFillHeight(context);
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  static double _defaultFillHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.65).clamp(360.0, 640.0);
  }
}

/// True when Search should show the dedicated empty state (no recordings).
bool searchHasNoRecordings(List<JournalEntry> entries) => entries.isEmpty;

/// Empty-query pane: dedicated search empty vs existing idle search UI.
Widget buildSearchEmptyQueryChild({
  required List<JournalEntry> entries,
  required Widget idleWhenSearchable,
}) {
  return searchHasNoRecordings(entries)
      ? const SearchEmptyState()
      : idleWhenSearchable;
}