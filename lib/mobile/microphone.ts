export type MicrophonePermissionState =
  | "unsupported"
  | "granted"
  | "denied"
  | "prompt"
  | "unknown";

export async function readMicrophonePermission(): Promise<MicrophonePermissionState> {
  if (typeof navigator === "undefined" || !navigator.mediaDevices?.getUserMedia) {
    return "unsupported";
  }

  try {
    const permissions = navigator.permissions;
    if (!permissions?.query) return "unknown";
    const status = await permissions.query({ name: "microphone" as PermissionName });
    return status.state as MicrophonePermissionState;
  } catch {
    return "unknown";
  }
}

export function microphonePermissionLabel(state: MicrophonePermissionState): string {
  const labels: Record<MicrophonePermissionState, string> = {
    unsupported: "Microphone API not available in this browser",
    granted: "Granted",
    denied: "Denied — recording will fail until enabled in system settings",
    prompt: "Will prompt on first recording",
    unknown: "Unknown until first recording attempt",
  };
  return labels[state];
}
