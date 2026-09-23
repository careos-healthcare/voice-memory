import type { Config } from "tailwindcss";

import { archiveDesignTokens } from "@voice-memory/shared/lib/design/archive-design-tokens";

const { color, primary, neutral, space, spacing, radius, type } =
  archiveDesignTokens;

function px(value: number): string {
  return `${value}px`;
}

function text(
  role: (typeof type)[keyof typeof type],
): [string, { lineHeight: string; letterSpacing: string }] {
  return [
    px(role.size),
    {
      lineHeight: String(role.lineHeight),
      letterSpacing: `${role.tracking}px`,
    },
  ];
}

const config: Config = {
  theme: {
    extend: {
      colors: {
        primary,
        neutral,
        archive: {
          background: color.light.background,
          surface: color.light.surface,
          "surface-alt": color.light.surfaceAlt,
          foreground: color.light.foreground,
          muted: color.light.muted,
          subtle: color.light.subtle,
          border: color.light.border,
          accent: color.light.accent,
          "accent-hover": color.light.accentHover,
          "accent-soft": color.light.accentSoft,
          "on-accent": color.light.onAccent,
          secondary: color.light.secondary,
          focus: color.light.focus,
          success: color.light.success,
          warning: color.light.warning,
          danger: color.light.danger,
        },
        "archive-dark": {
          background: color.dark.background,
          surface: color.dark.surface,
          foreground: color.dark.foreground,
          muted: color.dark.muted,
          border: color.dark.border,
          accent: color.dark.accent,
          "on-accent": color.dark.onAccent,
        },
      },
      spacing: {
        ...Object.fromEntries(
          Object.entries(spacing).map(([step, value]) => [step, px(value)]),
        ),
        "archive-xs": px(space.xs),
        "archive-sm": px(space.sm),
        "archive-md": px(space.md),
        "archive-lg": px(space.lg),
        "archive-xl": px(space.xl),
        "archive-touch": px(space.touch),
        "archive-control": px(space.control),
        "archive-button": px(space.button),
      },
      borderRadius: {
        "archive-control": px(radius.control),
        "archive-button": px(radius.button),
      },
      fontSize: {
        headline: text(type.headline),
        section: text(type.section),
        card: text(type.card),
        body: text(type.body),
        caption: text(type.caption),
        writing: text(type.writing),
      },
    },
  },
};

export default config;
