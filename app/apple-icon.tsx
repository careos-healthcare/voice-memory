import { ImageResponse } from "next/og";

import { APP_LOGO_INITIALS } from "@/lib/product/brand-copy";

export const size = { width: 180, height: 180 };
export const contentType = "image/png";

export default function AppleIcon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#09090b",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: 120,
            height: 120,
            borderRadius: 60,
            background: "rgba(139, 92, 246, 0.4)",
          }}
        >
          <span style={{ fontSize: 52, color: "#e9d5ff" }}>{APP_LOGO_INITIALS}</span>
        </div>
      </div>
    ),
    { ...size },
  );
}
