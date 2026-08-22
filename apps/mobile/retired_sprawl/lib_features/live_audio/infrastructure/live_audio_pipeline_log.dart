import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_proxy_url.dart';
import 'package:flutter/foundation.dart';

abstract final class LiveAudioPipelineLog {
  LiveAudioPipelineLog._();

  static void log(String message) {
    AppLogger.debug('ARCHIVEME_LIVE: $message');
  }

  static void sessionMinted({
    required String sessionId,
    String? proxyWebSocketUrl,
  }) {
    final urlSuffix = proxyWebSocketUrl == null
        ? ''
        : ' proxyUrl=${redactProxyWebSocketUrlForLog(proxyWebSocketUrl)}';
    log('session minted sessionId=$sessionId$urlSuffix');
  }

  static void connectStarted({
    required String sessionId,
    String? proxyWebSocketUrl,
  }) {
    final urlSuffix = proxyWebSocketUrl == null
        ? ''
        : ' proxyUrl=${redactProxyWebSocketUrlForLog(proxyWebSocketUrl)}';
    log('connect started sessionId=$sessionId$urlSuffix');
  }

  static void setupComplete({required String sessionId}) {
    log('setupComplete sessionId=$sessionId');
  }

  static void streamStarted({required String sessionId}) {
    log('stream started sessionId=$sessionId');
  }

  static void captureStarted({
    required int sampleRateHz,
    required int numChannels,
  }) {
    log('capture started sampleRateHz=$sampleRateHz numChannels=$numChannels');
  }

  static void captureStopped() {
    log('capture stopped');
  }

  static void pipelineFrameDropped() {
    log('audio pipeline ring buffer full; dropped oldest frame');
  }

  static void pcmChunkSent({
    required String sessionId,
    required int byteLength,
    required int chunkIndex,
  }) {
    if (chunkIndex == 1 || chunkIndex % 50 == 0) {
      log(
        'pcm chunk sent sessionId=$sessionId bytes=$byteLength chunkIndex=$chunkIndex',
      );
    }
  }

  static void audioChunkReceived({
    required int byteLength,
    required int chunkIndex,
    int? latencyMs,
  }) {
    log(
      'audio chunk received bytes=$byteLength chunkIndex=$chunkIndex'
      '${latencyMs == null ? '' : ' latencyMs=$latencyMs'}',
    );
  }

  static void reconnectStarted({
    required String sessionId,
    required int attempt,
    required String reason,
  }) {
    log(
      'reconnect started sessionId=$sessionId attempt=$attempt reason=$reason',
    );
  }

  static void reconnectSucceeded({
    required String sessionId,
    required int attempt,
  }) {
    log('reconnect succeeded sessionId=$sessionId attempt=$attempt');
  }

  static void sessionFault({
    required String reason,
    required int attempt,
    bool recoverable = false,
  }) {
    log(
      'session fault reason=$reason attempt=$attempt recoverable=$recoverable',
    );
  }

  static void bargeIn({required String source}) {
    log('barge-in playback flushed source=$source');
  }

  static void audioFocusPaused() {
    log('native audio focus lost; live capture paused');
  }

  static void audioFocusResumed() {
    log('native audio focus restored; live capture resumed');
  }

  static void audioFocusReactivated() {
    log('native audio focus re-requested before capture resume');
  }

  static void audioFocusResumeDeferred({required String reason}) {
    log('native audio focus resume deferred reason=$reason');
  }

  static void appLifecycleDetached() {
    log('app detached; terminating live session');
  }

  static void appLifecyclePaused() {
    log('app backgrounded; live capture paused');
  }

  static void appLifecycleResumed() {
    log('app foregrounded; evaluating live capture restoration');
  }

  static void sessionTerminated() {
    log('active live session terminated');
  }

  static void manualRecoveryStarted() {
    log('manual session recovery started');
  }

  static void manualRecoverySucceeded() {
    log('manual session recovery succeeded');
  }

  static void sessionFailure({
    required LiveVoiceErrorState errorState,
    required String reason,
  }) {
    log('session failure errorState=$errorState reason=$reason');
  }

  static void diagnostics(String summary) {
    log('diagnostics $summary');
  }

  static void disconnect({required String sessionId, String? reason}) {
    log(
      'disconnect sessionId=$sessionId'
      '${reason == null ? '' : ' reason=$reason'}',
    );
  }

  static void failure(String context, Object error) {
    log('failure context=$context error=$error');
  }

  static void offlineVaultInitialized({
    required String sessionId,
    required String pathSuffix,
  }) {
    log('offline vault initialized sessionId=$sessionId file=$pathSuffix');
  }

  static void offlineVaultClosed({
    required int frameCount,
    String? pathSuffix,
  }) {
    log(
      'offline vault closed frames=$frameCount'
      '${pathSuffix == null ? '' : ' file=$pathSuffix'}',
    );
  }

  static void offlineVaultActivated({required String reason}) {
    log('offline vault activated reason=$reason');
  }

  static void emergencyNetworkFallbackDeployed({required String sessionId}) {
    log(
      'Network dropped. Deploying emergency disk vault. sessionId=$sessionId',
    );
  }

  static void offlineVaultRegistered({
    required String sessionId,
    required int frameCount,
  }) {
    log('offline vault registered sessionId=$sessionId frames=$frameCount');
  }

  static void offlineVaultDiscarded({required String sessionId}) {
    log('offline vault discarded sessionId=$sessionId');
  }

  static void offlineVaultRecoveryStarted({required String sessionId}) {
    log('offline vault recovery started sessionId=$sessionId');
  }

  static void offlineVaultRecoveryAck({
    required String sessionId,
    required String recoveryAckId,
    bool duplicate = false,
  }) {
    log(
      'offline vault recovery ack sessionId=$sessionId ack=$recoveryAckId duplicate=$duplicate',
    );
  }

  static void offlineVaultRecoveryFailed({
    required String sessionId,
    required String reason,
  }) {
    log('offline vault recovery failed sessionId=$sessionId reason=$reason');
  }

  static void vaultRecoveryFinalized({required String sessionId}) {
    log('vault recovery finalized sessionId=$sessionId');
  }

  static void vaultRecoveryFailed({
    required String sessionId,
    required String error,
  }) {
    log('vault recovery failed sessionId=$sessionId error=$error');
  }
}