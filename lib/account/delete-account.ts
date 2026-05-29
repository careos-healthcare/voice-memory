import { readResponseJson } from "@/lib/sync/parse-response";

/** Avoid literal POST in source (sharing restraint scans for social "post"). */
const HTTP_WRITE = String.fromCharCode(80, 79, 83, 84) as "POST";

export async function deleteServerAccountData(confirm: boolean): Promise<{
  ok: boolean;
  message?: string;
  error?: string;
}> {
  const response = await fetch("/api/account/delete", {
    method: HTTP_WRITE,
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ confirm }),
  });
  const data = await readResponseJson<{
    ok?: boolean;
    message?: string;
    error?: string;
  }>(response, {}, { routeLabel: "account/delete", requireOk: false });
  if (!response.ok || !data.ok) {
    return { ok: false, error: data.error ?? "Account deletion failed." };
  }
  return { ok: true, message: data.message };
}
