import { redirect } from "next/navigation";

/** Legacy founder archive — consolidated into command center. */
export default function FounderArchiveRedirectPage() {
  redirect("/internal/activation");
}
