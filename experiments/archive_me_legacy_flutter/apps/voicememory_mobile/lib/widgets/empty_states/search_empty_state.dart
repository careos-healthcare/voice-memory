import 'package:flutter/material.dart';

import '../../design/empty_archive_experience.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_theme.dart';
import '../capture_entry_actions.dart';
import '../record/start_here_loader.dart';

/// Canonical copy for Search tab when there are no recordings.
abstract class SearchEmptyCopy {
  SearchEmptyCopy._();

  static const String title = 'Nothing to search yet';
  static const String body =
      'As you record thoughts, your archive becomes searchable.';
  static const String searchableForHeader = "You'll be able to search for:";
  static const List<String> searchableBullets = [
    "beliefs you've repeated",
    "topics you've talked about",
    'people, places, and events',
    'patterns that appear over time',
  ];
  static const String futureSearchHeader =
      'Months from now you might search for:';
  static const List<String> exampleSearchTerms = [
    'confidence',
    'burnout',
    'starting a business',
    "I'm not ready",
  ];
  static const String exampleSupporting =
      'and see how those ideas changed across your recordings.';
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
