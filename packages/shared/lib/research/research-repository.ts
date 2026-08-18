import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import {
  createHumanCase,
  createSyntheticCase,
  type HumanCaseInput,
  type HumanObservationCase,
  type SyntheticCaseInput,
  type SyntheticObservationCase,
} from "./research-domain";

interface StoredCaseCollection<T> {
  schemaVersion: 1;
  cases: T[];
}

const EMPTY_COLLECTION = Object.freeze({
  schemaVersion: 1 as const,
  cases: [],
});

export class JsonResearchRepository {
  readonly syntheticCasesPath: string;
  readonly humanCasesPath: string;

  constructor(readonly localRoot: string) {
    this.syntheticCasesPath = path.join(localRoot, "synthetic-cases.json");
    this.humanCasesPath = path.join(localRoot, "human-cases.json");
  }

  async addSynthetic(
    input: SyntheticCaseInput,
  ): Promise<SyntheticObservationCase> {
    const researchCase = createSyntheticCase(input);
    const [synthetic, human] = await Promise.all([
      this.listSynthetic(),
      this.listHuman(),
    ]);
    this.assertUniqueCaseId(researchCase.caseId, synthetic, human);
    await this.writeCollection(this.syntheticCasesPath, [
      ...synthetic,
      researchCase,
    ]);
    return researchCase;
  }

  async addHuman(input: HumanCaseInput): Promise<HumanObservationCase> {
    const researchCase = createHumanCase(input);
    const [synthetic, human] = await Promise.all([
      this.listSynthetic(),
      this.listHuman(),
    ]);
    this.assertUniqueCaseId(researchCase.caseId, synthetic, human);
    await this.writeCollection(this.humanCasesPath, [...human, researchCase]);
    return researchCase;
  }

  async listSynthetic(): Promise<readonly SyntheticObservationCase[]> {
    const stored = await this.readCollection<SyntheticCaseInput>(
      this.syntheticCasesPath,
    );
    return stored.cases.map(createSyntheticCase);
  }

  async listHuman(): Promise<readonly HumanObservationCase[]> {
    const stored = await this.readCollection<HumanCaseInput>(
      this.humanCasesPath,
    );
    return stored.cases.map(createHumanCase);
  }

  async findCase(caseId: string) {
    const [synthetic, human] = await Promise.all([
      this.listSynthetic(),
      this.listHuman(),
    ]);
    return (
      synthetic.find((item) => item.caseId === caseId) ??
      human.find((item) => item.caseId === caseId)
    );
  }

  private assertUniqueCaseId(
    caseId: string,
    synthetic: readonly SyntheticObservationCase[],
    human: readonly HumanObservationCase[],
  ): void {
    if ([...synthetic, ...human].some((item) => item.caseId === caseId)) {
      throw new Error(`Research case already exists: ${caseId}`);
    }
  }

  private async readCollection<T>(
    filePath: string,
  ): Promise<StoredCaseCollection<T>> {
    try {
      const parsed = JSON.parse(await readFile(filePath, "utf8")) as unknown;
      if (
        !parsed ||
        typeof parsed !== "object" ||
        (parsed as { schemaVersion?: unknown }).schemaVersion !== 1 ||
        !Array.isArray((parsed as { cases?: unknown }).cases)
      ) {
        throw new Error(`Invalid research collection: ${filePath}`);
      }
      return parsed as StoredCaseCollection<T>;
    } catch (error) {
      if (
        error &&
        typeof error === "object" &&
        "code" in error &&
        error.code === "ENOENT"
      ) {
        return EMPTY_COLLECTION as StoredCaseCollection<T>;
      }
      throw error;
    }
  }

  private async writeCollection<T>(
    filePath: string,
    cases: readonly T[],
  ): Promise<void> {
    await mkdir(this.localRoot, { recursive: true, mode: 0o700 });
    const tempPath = `${filePath}.${process.pid}.tmp`;
    const ordered = [...cases].sort((a, b) => {
      const left = (a as { caseId?: string }).caseId ?? "";
      const right = (b as { caseId?: string }).caseId ?? "";
      return left.localeCompare(right);
    });
    await writeFile(
      tempPath,
      `${JSON.stringify({ schemaVersion: 1, cases: ordered }, null, 2)}\n`,
      { encoding: "utf8", mode: 0o600 },
    );
    await rename(tempPath, filePath);
  }
}
