import { formatRelativeDate } from "@/lib/utils";

/** Journal/search list metadata — date only, no mood badges. */
export function EntryListRowMeta({ createdAt }: { createdAt: string }) {
  return (
    <span className="text-xs text-zinc-500">{formatRelativeDate(createdAt)}</span>
  );
}
