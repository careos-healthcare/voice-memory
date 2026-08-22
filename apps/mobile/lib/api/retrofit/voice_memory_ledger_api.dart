import 'dart:io';

import 'package:archiveme_mobile/api/models/ledger_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'voice_memory_ledger_api.g.dart';

@RestApi()
abstract class VoiceMemoryLedgerApi {
  factory VoiceMemoryLedgerApi(Dio dio, {String baseUrl}) =
      _VoiceMemoryLedgerApi;

  @POST('/api/ledger/bulk-import')
  Future<LedgerBulkImportResponseDto> bulkImportJson(
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/ledger/bulk-import')
  @MultiPart()
  Future<LedgerBulkImportResponseDto> bulkImportMultipart({
    @Part(name: 'entryId') required String entryId,
    @Part(name: 'sourceFile') required String sourceFile,
    @Part(name: 'audio') required File audio,
  });
}