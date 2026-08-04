import { SpatialNexusClient } from "@/components/spatial-nexus/SpatialNexusClient";

export const metadata = {
  title: "Spatial Nexus | ArchiveMe",
  description: "A private browser-local WebXR memory graph viewer.",
};

export default function SpatialNexusPage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <SpatialNexusClient />
    </div>
  );
}
