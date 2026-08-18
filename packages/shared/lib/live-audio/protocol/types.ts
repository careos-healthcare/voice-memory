export type BidiClientMessage =
  | LiveSetupClientMessage
  | LiveRealtimeInputClientMessage
  | LiveAudioStreamEndClientMessage;

export interface LiveSetupClientMessage {
  setup: {
    model: string;
    generationConfig: {
      responseModalities: ["AUDIO"];
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: {
            voiceName: string;
          };
        };
      };
    };
    systemInstruction?: {
      parts: Array<{ text: string }>;
    };
  };
}

export interface LiveRealtimeInputClientMessage {
  realtimeInput: {
    audio: {
      mimeType: string;
      data: string;
    };
  };
}

export interface LiveAudioStreamEndClientMessage {
  realtimeInput: {
    audioStreamEnd: true;
  };
}

export type LiveServerEvent =
  | { type: "setup_complete" }
  | { type: "audio_output"; pcmBase64: string; mimeType?: string }
  | { type: "input_transcription"; text: string }
  | { type: "output_transcription"; text: string }
  | { type: "interrupted" }
  | { type: "turn_complete" }
  | { type: "go_away"; timeLeft?: string }
  | { type: "error"; message: string }
  | { type: "unknown"; keys: string[] };
