import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
  buildApiErrorEnvelope,
} from "@/lib/server/api-error-response";
import { deleteUserDataCompletely } from "@/lib/user/delete-user-data";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function DELETE() {
  const session = await getServerSession();
  if (!session?.userId) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "user/data",
    });
  }

  try {
    const result = await deleteUserDataCompletely(session.userId, session.email);

    if (!result.ok) {
      const built = buildApiErrorEnvelope({ code: "PARTIAL_DELETION", status: 502 });
      return NextResponse.json(
        {
          ok: false,
          deleted: result.deleted,
          counts: result.counts,
          ...built.body,
        },
        { status: 502 },
      );
    }

    return NextResponse.json({
      ok: true,
      deleted: {
        relational_data: result.deleted.relational_data,
        vectors: result.deleted.vectors,
        audio_files: result.deleted.audio_files,
      },
      counts: result.counts,
      message: "All user data deleted: relational_data, vectors, and audio_files.",
    });
  } catch (error) {
    console.error("DELETE /api/user/data failed", error);
    return apiErrorFromException(error, {
      code: "USER_DATA_DELETE_FAILED",
      route: "user/data",
      logEvent: "api_error",
    });
  }
}
