/**
 * Shared ArchiveMe tokens for web and Flutter.
 *
 * Light values match the consumer mobile palette. Dark values match the web
 * deep-dark tone. Complex components should use the light set so both
 * platforms paint the same surface, type, and spacing.
 */
export const archiveDesignTokens = {
  color: {
    light: {
      background: "#F8F6F1",
      surface: "#FFFFFF",
      surfaceAlt: "#F3F0EA",
      foreground: "#172033",
      muted: "#667085",
      subtle: "#4B5568",
      border: "#E5E0D8",
      accent: "#2563EB",
      accentHover: "#1D4ED8",
      accentSoft: "#EAF2FF",
      onAccent: "#FFFFFF",
      secondary: "#0F766E",
      focus: "#1D4ED8",
      success: "#15803D",
      warning: "#B45309",
      danger: "#DC2626",
    },
    dark: {
      background: "#09090B",
      surface: "#09090B",
      foreground: "#FAFAFA",
      muted: "#A1A1AA",
      border: "rgba(255, 255, 255, 0.06)",
      accent: "#8B5CF6",
      onAccent: "#FFFFFF",
    },
  },
  space: {
    xs: 8,
    sm: 16,
    md: 24,
    lg: 32,
    xl: 48,
    touch: 44,
    control: 48,
    button: 56,
  },
  radius: {
    control: 16,
    button: 28,
  },
  type: {
    headline: { size: 32, weight: 700, lineHeight: 1.35, tracking: -0.4 },
    section: { size: 22, weight: 600, lineHeight: 1.4, tracking: 0 },
    card: { size: 18, weight: 600, lineHeight: 1.4, tracking: 0 },
    body: { size: 16, weight: 400, lineHeight: 1.5, tracking: 0 },
    caption: { size: 14, weight: 400, lineHeight: 1.45, tracking: 0 },
    writing: { size: 17, weight: 400, lineHeight: 1.7, tracking: 0.15 },
  },
} as const;

export type ArchiveDesignTokens = typeof archiveDesignTokens;
