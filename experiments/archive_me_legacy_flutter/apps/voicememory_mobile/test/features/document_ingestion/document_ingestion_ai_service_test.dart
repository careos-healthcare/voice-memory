import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_ingestion_ai_service.dart';

void main() {
  group('DocumentIngestionAiService privacy boundary', () {
    test('sends only opaque metadata and explicitly approved text', () {
      final payload = DocumentIngestionAiService.buildPayload(const [
        ApprovedDocumentExcerpt(
          documentId: 'doc_opaque_1234',
          chunkId: 'chunk_opaque_1234',
          text: 'Only this selected paragraph may leave the device.',
          format: 'pdf',
        ),
      ]);

      expect(payload.keys, unorderedEquals(['documentId', 'format', 'chunks']));
      expect(payload.toString(), isNot(contains('https://')));
      expect(payload.toString(), isNot(contains('/Users/')));
      expect(payload.toString(), isNot(contains('journal')));
      expect(
        payload.toString(),
        contains('Only this selected paragraph may leave the device.'),
      );
    });

    test(
      'rejects empty, duplicate, mixed-document and oversized selections',
      () {
        expect(
          () => DocumentIngestionAiService.buildPayload(const []),
          throwsFormatException,
        );
        expect(
          () => DocumentIngestionAiService.buildPayload(const [
            ApprovedDocumentExcerpt(
              documentId: 'doc_opaque_1234',
              chunkId: 'same_chunk_1234',
              text: 'one',
              format: 'pdf',
            ),
            ApprovedDocumentExcerpt(
              documentId: 'doc_opaque_1234',
              chunkId: 'same_chunk_1234',
              text: 'two',
              format: 'pdf',
            ),
          ]),
          throwsFormatException,
        );
        expect(
          () => DocumentIngestionAiService.buildPayload(const [
            ApprovedDocumentExcerpt(
              documentId: 'doc_opaque_1234',
              chunkId: 'chunk_opaque_1234',
              text: 'one',
              format: 'pdf',
            ),
            ApprovedDocumentExcerpt(
              documentId: 'doc_opaque_5678',
              chunkId: 'chunk_opaque_5678',
              text: 'two',
              format: 'pdf',
            ),
          ]),
          throwsFormatException,
        );
        expect(
          () => DocumentIngestionAiService.buildPayload([
            ApprovedDocumentExcerpt(
              documentId: 'doc_opaque_1234',
              chunkId: 'chunk_opaque_1234',
              text: 'x' * (DocumentIngestionAiService.maxChunkCharacters + 1),
              format: 'pdf',
            ),
          ]),
          throwsFormatException,
        );
      },
    );

    test('accepts backend schema and rejects invented citations', () {
      final response = <String, Object>{
        'concepts': [
          {
            'id': 'concept_alpha',
            'label': 'Alpha',
            'kind': 'theme',
            'summary': 'A grounded concept.',
            'citationChunkIds': ['chunk_opaque_1234'],
          },
        ],
        'entities': [
          {
            'id': 'entity_alpha',
            'label': 'Alpha team',
            'type': 'organization',
            'citationChunkIds': ['chunk_opaque_1234'],
          },
        ],
        'arguments': [
          {
            'id': 'argument_alpha',
            'claim': 'The source makes a claim.',
            'stance': 'supports',
            'citationChunkIds': ['chunk_opaque_1234'],
          },
        ],
        'categoryTags': ['research'],
        'relationships': <Map<String, Object>>[],
      };
      final parsed = DocumentIngestionAiService.parseResponse(
        response,
        allowedChunkIds: {'chunk_opaque_1234'},
      );
      expect(parsed.concepts.single.label, 'Alpha');
      expect(parsed.entities.single.type, 'organization');
      expect(parsed.arguments.single.stance, 'supports');

      final invalid = Map<String, Object>.from(response)
        ..['concepts'] = [
          {
            'id': 'concept_alpha',
            'label': 'Alpha',
            'kind': 'theme',
            'summary': 'A grounded concept.',
            'citationChunkIds': ['invented_chunk'],
          },
        ];
      expect(
        () => DocumentIngestionAiService.parseResponse(
          invalid,
          allowedChunkIds: {'chunk_opaque_1234'},
        ),
        throwsFormatException,
      );
    });
  });
}
