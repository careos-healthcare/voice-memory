import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

export default [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
  {
    ignores: ["node_modules/**", ".next/**", "dist/**"],
  },
  {
    files: ["**/*.{ts,tsx}"],
    ignores: ["src/internal/**"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: [
                "@/src/internal/clinical",
                "@/src/internal/clinical/*",
                "**/src/internal/clinical",
                "**/src/internal/clinical/*",
              ],
              message:
                "Clinical quarantine modules are internal-only. Import from src/internal/** wrappers, never from public routes or shared client types.",
            },
          ],
        },
      ],
    },
  },
];
