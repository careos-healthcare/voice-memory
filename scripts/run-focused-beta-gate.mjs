#!/usr/bin/env node
import { main } from "./release/focused-beta-gate-runner.mjs";

process.exit(main(process.argv.slice(2)));
