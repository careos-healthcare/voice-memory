import 'dart:typed_data';

/// How the finished book is bound.
enum BookCover { hardcover, softcover }

/// Page margins in millimetres. [insideMm] is the binding edge.
class BookMargins {
  const BookMargins({
    this.topMm = 15,
    this.bottomMm = 15,
    this.outsideMm = 12,
    this.insideMm = 20,
  });

  final double topMm;
  final double bottomMm;
  final double outsideMm;
  final double insideMm;

  BookMargins copyWith({
    double? topMm,
    double? bottomMm,
    double? outsideMm,
    double? insideMm,
  }) {
    return BookMargins(
      topMm: topMm ?? this.topMm,
      bottomMm: bottomMm ?? this.bottomMm,
      outsideMm: outsideMm ?? this.outsideMm,
      insideMm: insideMm ?? this.insideMm,
    );
  }
}

/// Cover and margins for one print-on-demand order.
class BookOptions {
  const BookOptions({
    required this.cover,
    this.margins = const BookMargins(),
  });

  final BookCover cover;
  final BookMargins margins;
}

/// Thrown when a print upload is attempted before the person agrees.
class PodConsentRequired implements Exception {
  const PodConsentRequired();
}

/// Thrown when an order is created before the PDF has been accepted for upload.
class PodUploadRequired implements Exception {
  const PodUploadRequired();
}

/// Stub for a print partner. Nothing leaves the device.
class PodApiService {
  bool consentGranted = false;
  Uint8List? uploadedPdf;
  BookOptions? lastOrder;

  void grantUploadConsent() {
    consentGranted = true;
  }

  /// Accepts the finished PDF only after consent. No network call.
  Future<void> uploadPdfToPrinter(Uint8List pdf) async {
    if (!consentGranted) throw const PodConsentRequired();
    if (pdf.isEmpty) {
      throw ArgumentError.value(pdf, 'pdf', 'A book PDF is required');
    }
    uploadedPdf = Uint8List.fromList(pdf);
  }

  /// Records the cover and margins for a PDF that was already accepted.
  Future<void> createPrintOrder(BookOptions options) async {
    if (!consentGranted) throw const PodConsentRequired();
    if (uploadedPdf == null) throw const PodUploadRequired();
    lastOrder = options;
  }
}
