import { LIVE_INPUT_AUDIO_MIME } from "@/lib/live-audio/constants";
import type {
  LiveAudioStreamEndClientMessage,
  LiveRealtimeInputClientMessage,
} from "@/lib/live-audio/protocol/types";

export function buildLiveAudioInputMessage(
  pcmBytes: Uint8Array | Buffer,
): LiveRealtimeInputClientMessage {
  return {
    realtimeInput: {
      audio: {
        mimeType: LIVE_INPUT_AUDIO_MIME,
        data: Buffer.from(pcmBytes).toString("base64"),
      },
    },
  };
}

export function buildLiveAudioStreamEndMessage(): LiveAudioStreamEndClientMessage {
  return {
    realtimeInput: {
      audioStreamEnd: true,
    },
  };
}
