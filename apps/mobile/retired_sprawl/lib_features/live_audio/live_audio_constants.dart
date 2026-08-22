import 'package:archiveme_mobile/security/api_usage_guard.dart' show ApiUsageGuard;

/// PCM input for Gemini Live — 16-bit LE @ 16 kHz.
const liveInputAudioMime = 'audio/pcm;rate=16000';

/// Input sample rate required by Gemini Live PCM frames.
const liveInputSampleRateHz = 16000;

/// Input channel count for Gemini Live PCM frames.
const liveInputNumChannels = 1;

/// Nominal PCM frame duration used by the isolate pipeline.
const liveInputFrameDurationMs = 20;

/// PCM output from Gemini Live — 16-bit LE @ 24 kHz.
const liveOutputSampleRateHz = 24000;

/// Output channel count for Gemini Live PCM playback.
const liveOutputNumChannels = 1;

/// PCM output from Gemini Live — 16-bit LE @ 24 kHz.
const liveOutputAudioMime = 'audio/pcm;rate=24000';

/// Query parameter used to authenticate with the backend live-audio proxy.
const liveSessionTokenQueryParam = 'sessionToken';

/// Scope key prefix for [ApiUsageGuard] live session mint attempts.
const liveAudioUsageScopePrefix = 'live_audio_session';