#!/usr/bin/env node
import { spawnSync } from "node:child_process";
spawnSync("node", ["scripts/validate-validator-confidence.mjs"], { stdio: "inherit" });
