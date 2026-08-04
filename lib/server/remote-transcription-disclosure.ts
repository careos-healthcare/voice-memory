import { NextResponse } from "next/server";

export const REMOTE_TRANSCRIPTION_DISCLOSURE_VERSION = "1";
export const REMOTE_TRANSCRIPTION_DISCLOSURE_HEADER =
  "x-vm-remote-transcription-disclosure-version";

const VERSION_PATTERN = /^[1-9]\d*$/;

export function requireRemoteTranscriptionDisclosure(
  request: Request,
): NextResponse | null {
  const raw = request.headers.get(REMOTE_TRANSCRIPTION_DISCLOSURE_HEADER);
  if (raw === null || raw.trim() === "") {
    return NextResponse.json(
      {
        error: "Current remote transcription disclosure acceptance is required.",
        code: "remoteDisclosureRequired",
        supportedVersion: REMOTE_TRANSCRIPTION_DISCLOSURE_VERSION,
      },
      { status: 428 },
    );
  }

  if (raw !== raw.trim() || !VERSION_PATTERN.test(raw)) {
    return NextResponse.json(
      {
        error: "Remote transcription disclosure version is malformed.",
        code: "remoteDisclosureVersionMalformed",
        supportedVersion: REMOTE_TRANSCRIPTION_DISCLOSURE_VERSION,
      },
      { status: 400 },
    );
  }

  if (raw !== REMOTE_TRANSCRIPTION_DISCLOSURE_VERSION) {
    return NextResponse.json(
      {
        error: "Current remote transcription disclosure acceptance is required.",
        code: "remoteDisclosureVersionUnsupported",
        supportedVersion: REMOTE_TRANSCRIPTION_DISCLOSURE_VERSION,
      },
      { status: 428 },
    );
  }

  return null;
}
