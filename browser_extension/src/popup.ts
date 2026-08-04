import {
  clip,
  pair,
  pairingStatus,
  type ClipPayload,
  type PairingInvitation,
} from "./bridge.js";

const api: ExtensionApi =
  typeof browser !== "undefined" ? browser : chrome;

function element<T extends HTMLElement>(id: string): T {
  const value = document.getElementById(id);
  if (!value) throw new Error(`Missing element: ${id}`);
  return value as T;
}

function status(message: string, error = false): void {
  const target = element<HTMLParagraphElement>("status");
  target.textContent = message;
  target.dataset.error = String(error);
}

async function capture(): Promise<ClipPayload> {
  const [tab] = await api.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id || !tab.url) throw new Error("No active web page");
  const [result] = await api.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => ({
      content: document.documentElement.outerHTML,
      selection: window.getSelection()?.toString() ?? "",
      description:
        document.querySelector('meta[name="description"]')?.getAttribute("content") ??
        "",
      language: document.documentElement.lang,
    }),
  });
  const page = result?.result;
  if (!page) throw new Error("Could not read this page");
  let screenshot: string | undefined;
  if (element<HTMLInputElement>("include-screenshot").checked) {
    screenshot = await api.tabs.captureVisibleTab(tab.windowId, {
      format: "jpeg",
      quality: 70,
    });
    screenshot = screenshot.split(",", 2)[1];
  }
  const stored = await api.storage.local.get(["pendingHighlights"]);
  const highlights = Array.isArray(stored.pendingHighlights)
    ? stored.pendingHighlights.filter(
        (item): item is string => typeof item === "string",
      )
    : [];
  return {
    url: tab.url,
    title: tab.title ?? "Web clip",
    content: page.content,
    contentType: "text/html",
    capturedAt: new Date().toISOString(),
    selection: page.selection,
    highlights,
    metadata: {
      description: page.description,
      language: page.language,
    },
    screenshot,
  };
}

element<HTMLButtonElement>("pair").addEventListener("click", async () => {
  try {
    const invitation = JSON.parse(
      element<HTMLTextAreaElement>("pairing-code").value,
    ) as PairingInvitation;
    await pair(invitation);
    status("Paired securely with the local vault.");
  } catch (error) {
    status(String(error), true);
  }
});

element<HTMLButtonElement>("clip-page").addEventListener("click", async () => {
  try {
    status("Encrypting and clipping…");
    const result = await clip(await capture());
    await api.storage.local.remove(["pendingHighlights"]);
    status(`Stored locally · ${String(result.chunkCount)} semantic chunks`);
  } catch (error) {
    status(String(error), true);
  }
});

void pairingStatus().then((paired) => {
  status(paired ? "Paired · local bridge ready" : "Paste a QR pairing payload");
});
