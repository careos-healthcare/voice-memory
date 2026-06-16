import { FounderTestShell } from "@/app/internal/founder-test/FounderTestShell";
import { buildDesignConsistencyFileReport } from "@/lib/internal/design-consistency-file-audit";

export default function FounderTestPage() {
  const designReport = buildDesignConsistencyFileReport();
  return <FounderTestShell designReport={designReport} />;
}
