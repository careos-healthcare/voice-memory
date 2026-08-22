#!/usr/bin/env node
import { loadManifest, mainStatus } from "./release/focused-beta-core.mjs";

mainStatus(process.argv.slice(2));
