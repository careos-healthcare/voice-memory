#!/usr/bin/env node
import { mainVerify } from "./release/focused-beta-core.mjs";

const code = mainVerify(process.argv.slice(2));
process.exit(code);
