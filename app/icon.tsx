import { ImageResponse } from "next/og";

export const size = { width: 512, height: 512 };
export const contentType = "image/png";

export default function Icon() {
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
          borderRadius: 96,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: 280,
            height: 280,
            borderRadius: 140,
            background: "rgba(139, 92, 246, 0.35)",
            border: "4px solid rgba(167, 139, 250, 0.6)",
          }}
        >
          <span style={{ fontSize: 120, color: "#e9d5ff" }}>VM</span>
        </div>
      </div>
    ),
    { ...size },
  );
}
