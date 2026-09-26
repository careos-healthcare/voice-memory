import 'package:archiveme_mobile/features/export/book_exporter.dart';

/// Same cover math as the Lulu cover-dimensions fallback on the server.
abstract final class LuluCover {
  LuluCover._();

  static const bleedInches = 0.125;
  static const spineInchesPerPage = 0.002252;

  static double trimWidthInches(BookPageSize size) {
    return size == BookPageSize.usTrade ? 6 : 5.83;
  }

  static double widthInches({
    required int pageCount,
    required double trimWidthInches,
  }) {
    final spine = pageCount * spineInchesPerPage;
    final width = trimWidthInches * 2 + spine + bleedInches * 2;
    return (width * 10000).round() / 10000;
  }
}

class PrintedBookQuote {
  const PrintedBookQuote({
    required this.pageCount,
    required this.coverWidthInches,
    required this.printCostCents,
    required this.shippingCents,
    required this.marginCents,
  });

  final int pageCount;
  final double coverWidthInches;
  final int printCostCents;
  final int shippingCents;
  final int marginCents;

  int get totalCents => printCostCents + shippingCents + marginCents;

  factory PrintedBookQuote.forPages({
    required int pageCount,
    required BookPageSize size,
    int printCostCents = 1200,
    int shippingCents = 450,
  }) {
    final margin = ((printCostCents + shippingCents) * 2000 / 10000).round();
    return PrintedBookQuote(
      pageCount: pageCount,
      coverWidthInches: LuluCover.widthInches(
        pageCount: pageCount,
        trimWidthInches: LuluCover.trimWidthInches(size),
      ),
      printCostCents: printCostCents,
      shippingCents: shippingCents,
      marginCents: margin,
    );
  }
}
