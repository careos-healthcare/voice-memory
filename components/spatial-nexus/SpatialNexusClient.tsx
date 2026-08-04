"use client";

import { useEffect, useRef, useState } from "react";
import {
  MAX_SPATIAL_SNAPSHOT_BYTES,
  parseSpatialNexusSnapshot,
  type SpatialNexusSnapshot,
} from "@/lib/spatial-nexus/snapshot";

type XRSessionLike = {
  end(): Promise<void>;
  addEventListener(type: "end", listener: () => void, options?: { once: boolean }): void;
};

type XRSystemLike = {
  isSessionSupported(mode: "immersive-vr" | "immersive-ar"): Promise<boolean>;
  requestSession(
    mode: "immersive-vr" | "immersive-ar",
    options?: { optionalFeatures?: string[] },
  ): Promise<XRSessionLike>;
};

function xrSystem(): XRSystemLike | undefined {
  return (navigator as Navigator & { xr?: XRSystemLike }).xr;
}

export function SpatialNexusClient() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [snapshot, setSnapshot] = useState<SpatialNexusSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [xrAvailable, setXrAvailable] = useState(false);
  const [session, setSession] = useState<XRSessionLike | null>(null);

  useEffect(() => {
    let cancelled = false;
    const xr = xrSystem();
    if (!xr) return;
    void Promise.all([
      xr.isSessionSupported("immersive-vr"),
      xr.isSessionSupported("immersive-ar"),
    ]).then(([vr, ar]) => {
      if (!cancelled) setXrAvailable(vr || ar);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !snapshot) return;
    return renderSnapshot(canvas, snapshot);
  }, [snapshot]);

  async function importSnapshot(file: File | undefined) {
    setError(null);
    setSnapshot(null);
    if (!file) return;
    if (file.size > MAX_SPATIAL_SNAPSHOT_BYTES) {
      setError("This snapshot exceeds the 2 MB local rendering limit.");
      return;
    }
    try {
      const decoded: unknown = JSON.parse(await file.text());
      setSnapshot(parseSpatialNexusSnapshot(decoded));
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : "The snapshot could not be read.",
      );
    }
  }

  async function enterXr() {
    const xr = xrSystem();
    if (!xr || !xrAvailable) return;
    try {
      const next = await xr.requestSession("immersive-vr", {
        optionalFeatures: ["local-floor", "bounded-floor", "hand-tracking"],
      });
      next.addEventListener("end", () => setSession(null), { once: true });
      setSession(next);
    } catch {
      setError("The browser declined the immersive session.");
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-6xl px-4 py-8 text-zinc-100">
      <header className="mb-6">
        <p className="text-sm uppercase tracking-[0.2em] text-cyan-300">
          Local spatial canvas
        </p>
        <h1 className="text-3xl font-semibold">The Spatial Nexus</h1>
        <p className="mt-2 max-w-2xl text-zinc-400">
          Import a privacy-minimized .spatial.json file. It stays in this
          browser tab and is never uploaded.
        </p>
      </header>

      <section className="rounded-3xl border border-white/10 bg-zinc-950/80 p-4">
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <label className="cursor-pointer rounded-full border border-cyan-300/40 px-4 py-2">
            Import local snapshot
            <input
              className="sr-only"
              type="file"
              accept=".json,.spatial.json,application/json"
              onChange={(event) => void importSnapshot(event.target.files?.[0])}
            />
          </label>
          <button
            type="button"
            disabled={!snapshot || !xrAvailable || session !== null}
            onClick={() => void enterXr()}
            className="rounded-full bg-cyan-300 px-4 py-2 font-medium text-zinc-950 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {session ? "Immersive session active" : "Enter WebXR"}
          </button>
          {session ? (
            <button
              type="button"
              onClick={() => void session.end()}
              className="rounded-full border border-white/20 px-4 py-2"
            >
              Exit immersive
            </button>
          ) : null}
          <span className="text-sm text-zinc-400">
            WebXR: {xrAvailable ? "available" : "unavailable"}
          </span>
        </div>

        {error ? (
          <p role="alert" className="mb-3 text-sm text-red-300">
            {error}
          </p>
        ) : null}
        <canvas
          ref={canvasRef}
          aria-label={
            snapshot
              ? `Spatial graph with ${snapshot.nodes.length} memory nodes`
              : "Empty Spatial Nexus viewport"
          }
          className="h-[70vh] w-full rounded-2xl bg-black"
        />
        {!snapshot ? (
          <p className="py-8 text-center text-zinc-500">
            Export a snapshot from the Flutter Spatial Nexus control hub, then
            choose it here.
          </p>
        ) : null}
      </section>
    </main>
  );
}

function renderSnapshot(
  canvas: HTMLCanvasElement,
  snapshot: SpatialNexusSnapshot,
): () => void {
  const gl = canvas.getContext("webgl2", {
    alpha: false,
    antialias: true,
    preserveDrawingBuffer: false,
  });
  if (!gl) return () => undefined;
  const program = createProgram(gl);
  const buffer = gl.createBuffer();
  if (!buffer) return () => gl.deleteProgram(program);
  const values = new Float32Array(snapshot.nodes.length * 4);
  snapshot.nodes.forEach((node, index) => {
    values[index * 4] = node.position.x;
    values[index * 4 + 1] = node.position.y;
    values[index * 4 + 2] = node.position.z;
    values[index * 4 + 3] = node.valence;
  });
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, values, gl.STATIC_DRAW);
  gl.useProgram(program);
  const position = gl.getAttribLocation(program, "particle");
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 4, gl.FLOAT, false, 0, 0);
  const angle = gl.getUniformLocation(program, "angle");
  const aspect = gl.getUniformLocation(program, "aspect");
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let frame = 0;
  let stopped = false;

  const draw = (time: number) => {
    if (stopped) return;
    const ratio = window.devicePixelRatio || 1;
    const width = Math.max(1, Math.floor(canvas.clientWidth * ratio));
    const height = Math.max(1, Math.floor(canvas.clientHeight * ratio));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    gl.viewport(0, 0, width, height);
    gl.clearColor(0.015, 0.02, 0.06, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.uniform1f(angle, reduced ? 0 : time * 0.00005);
    gl.uniform1f(aspect, width / height);
    gl.drawArrays(gl.POINTS, 0, snapshot.nodes.length);
    frame = requestAnimationFrame(draw);
  };
  frame = requestAnimationFrame(draw);
  return () => {
    stopped = true;
    cancelAnimationFrame(frame);
    gl.deleteBuffer(buffer);
    gl.deleteProgram(program);
  };
}

function createProgram(gl: WebGL2RenderingContext): WebGLProgram {
  const vertex = compile(
    gl,
    gl.VERTEX_SHADER,
    `#version 300 es
    in vec4 particle;
    uniform float angle;
    uniform float aspect;
    out float valence;
    void main() {
      float c = cos(angle);
      float s = sin(angle);
      vec3 p = vec3(
        particle.x * c - particle.z * s,
        particle.y,
        particle.x * s + particle.z * c
      );
      float depth = max(1.0, 8.0 - p.z);
      gl_Position = vec4(p.x * 1.7 / (depth * aspect), p.y * 1.7 / depth, 0.0, 1.0);
      gl_PointSize = max(3.0, 70.0 / depth);
      valence = particle.w;
    }`,
  );
  const fragment = compile(
    gl,
    gl.FRAGMENT_SHADER,
    `#version 300 es
    precision highp float;
    in float valence;
    out vec4 color;
    void main() {
      float d = distance(gl_PointCoord, vec2(0.5));
      if (d > 0.5) discard;
      vec3 cold = vec3(0.32, 0.48, 1.0);
      vec3 warm = vec3(1.0, 0.42, 0.34);
      color = vec4(mix(cold, warm, valence * 0.5 + 0.5), 1.0 - d);
    }`,
  );
  const program = gl.createProgram();
  if (!program) throw new Error("WebGL program allocation failed.");
  gl.attachShader(program, vertex);
  gl.attachShader(program, fragment);
  gl.linkProgram(program);
  gl.deleteShader(vertex);
  gl.deleteShader(fragment);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const message = gl.getProgramInfoLog(program) ?? "WebGL link failed.";
    gl.deleteProgram(program);
    throw new Error(message);
  }
  return program;
}

function compile(
  gl: WebGL2RenderingContext,
  kind: number,
  source: string,
): WebGLShader {
  const shader = gl.createShader(kind);
  if (!shader) throw new Error("WebGL shader allocation failed.");
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const message = gl.getShaderInfoLog(shader) ?? "WebGL compile failed.";
    gl.deleteShader(shader);
    throw new Error(message);
  }
  return shader;
}
