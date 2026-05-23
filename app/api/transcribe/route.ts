import { NextResponse } from "next/server";

import { getOpenAIClient } from "@/lib/openai";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const audio = formData.get("audio");

    if (!(audio instanceof File) || audio.size === 0) {
      return NextResponse.json(
        { error: "Audio file is required" },
        { status: 400 },
      );
    }

    const openai = getOpenAIClient();
    const transcription = await openai.audio.transcriptions.create({
      file: audio,
      model: "whisper-1",
      language: "en",
    });

    const transcript = transcription.text?.trim();

    if (!transcript) {
      return NextResponse.json(
        { error: "Could not detect speech in the recording" },
        { status: 422 },
      );
    }

    return NextResponse.json({ transcript });
  } catch (error) {
    console.error("Transcription failed:", error);
    const message =
      error instanceof Error ? error.message : "Transcription failed";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
