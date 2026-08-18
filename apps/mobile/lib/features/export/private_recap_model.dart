/// What a private recap is about.
enum PrivateRecapType { keyMoment, pattern, weekly, monthly, selectedRange }

extension PrivateRecapTypeIds on PrivateRecapType {
  String get id => name;
}

/// A private, keepable recap of what ArchiveMe noticed.
///
/// This is a plain-text snapshot the user can copy, share, or save for
/// themselves. It is never posted anywhere — there is no social surface.
class PrivateRecap {
  const PrivateRecap({
    required this.type,
    required this.title,
    this.dateRange,
    this.summary,
    this.usefulMoments = const [],
    this.nextCheck,
  });

  final PrivateRecapType type;
  final String title;
  final String? dateRange;
  final String? summary;
  final List<String> usefulMoments;
  final String? nextCheck;

  /// Trailing line attached to every recap.
  static const String madeWith = 'Made with ArchiveMe';

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  /// The recap as plain text, in a fixed, readable layout:
  ///
  /// ```
  /// Title
  /// Date range
  ///
  /// Summary
  ///
  /// Useful moments
  /// - ...
  ///
  /// Next check
  /// ...
  ///
  /// Made with ArchiveMe
  /// ```
  ///
  /// Empty sections are omitted so the text never has dangling headings.
  String get plainText {
    final blocks = <String>[];

    final header = StringBuffer(title.trim());
    final range = (dateRange ?? '').trim();
    if (range.isNotEmpty) {
      header.write('\n');
      header.write(range);
    }
    blocks.add(header.toString());

    final summaryText = (summary ?? '').trim();
    if (summaryText.isNotEmpty) {
      blocks.add(summaryText);
    }

    final moments = usefulMoments
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    if (moments.isNotEmpty) {
      final buffer = StringBuffer('Useful moments');
      for (final m in moments) {
        buffer.write('\n- ');
        buffer.write(m);
      }
      blocks.add(buffer.toString());
    }

    if (hasNextCheck) {
      blocks.add('Next check\n${nextCheck!.trim()}');
    }

    blocks.add(madeWith);

    return blocks.join('\n\n');
  }
}