import '../explainable_conclusion/explainable_conclusion.dart';

/// The route that opens the exact saved moment a citation came from.
///
/// Every surface that quotes evidence builds its link here, so a quote is
/// always one tap from the words it was taken from, at the right position in
/// the recording when there is one.
String evidenceRouteFor(TranscriptEvidenceCitation citation) => Uri(
  path: '/entry/${citation.entryId}',
  queryParameters: {
    if (citation.audioTimestampMs != null)
      'audioTimestampMs': citation.audioTimestampMs.toString(),
  },
).toString();
