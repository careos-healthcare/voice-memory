import { runDocumentIngestionContractTests } from "../lib/reliability/document-ingestion-contract-tests.ts";

await runDocumentIngestionContractTests();
console.log("Document ingestion contract tests passed.");
