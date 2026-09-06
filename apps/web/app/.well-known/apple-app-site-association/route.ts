import { NextResponse } from "next/server";

// Served with an explicit route handler, not a static file: Next's default
// static serving guesses content-type from the file extension, and this file
// has none by Apple's own spec. Served as application/octet-stream, it
// silently downloads instead of verifying -- confirmed by multiple real
// reports of exactly this failure. A route handler sidesteps the guess.
const association = {
  applinks: {
    apps: [],
    details: [
      {
        appID: "4D9MAHRDS3.com.voicememory.mobile",
        paths: ["/caregiver/*"],
      },
    ],
  },
};

export async function GET() {
  return NextResponse.json(association);
}
