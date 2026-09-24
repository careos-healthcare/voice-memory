import { ImageResponse } from "next/og";

export const alt = "Thoughtprint — a private voice journal";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          background: "#09090b",
          color: "#fafafa",
          padding: "80px",
          fontSize: 64,
          fontWeight: 600,
          letterSpacing: -1,
        }}
      >
        <div style={{ fontSize: 28, color: "#c4b5fd", marginBottom: 24 }}>Thoughtprint</div>
        A private voice journal that remembers what you actually said.
      </div>
    ),
    { ...size },
  );
}
