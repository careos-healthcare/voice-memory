import { clip, pair, pairingStatus, } from "./bridge.js";
const api = typeof browser !== "undefined" ? browser : chrome;
function element(id) {
    const value = document.getElementById(id);
    if (!value)
        throw new Error(`Missing element: ${id}`);
    return value;
}
function status(message, error = false) {
    const target = element("status");
    target.textContent = message;
    target.dataset.error = String(error);
}
async function capture() {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id || !tab.url)
        throw new Error("No active web page");
    const [result] = await api.scripting.executeScript({
        target: { tabId: tab.id },
        func: () => ({
            content: document.documentElement.outerHTML,
            selection: window.getSelection()?.toString() ?? "",
            description: document.querySelector('meta[name="description"]')?.getAttribute("content") ??
                "",
            language: document.documentElement.lang,
        }),
    });
    const page = result?.result;
    if (!page)
        throw new Error("Could not read this page");
    let screenshot;
    if (element("include-screenshot").checked) {
        screenshot = await api.tabs.captureVisibleTab(tab.windowId, {
            format: "jpeg",
            quality: 70,
        });
        screenshot = screenshot.split(",", 2)[1];
    }
    const stored = await api.storage.local.get(["pendingHighlights"]);
    const highlights = Array.isArray(stored.pendingHighlights)
        ? stored.pendingHighlights.filter((item) => typeof item === "string")
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
element("pair").addEventListener("click", async () => {
    try {
        const invitation = JSON.parse(element("pairing-code").value);
        await pair(invitation);
        status("Paired securely with the local vault.");
    }
    catch (error) {
        status(String(error), true);
    }
});
element("clip-page").addEventListener("click", async () => {
    try {
        status("Encrypting and clipping…");
        const result = await clip(await capture());
        await api.storage.local.remove(["pendingHighlights"]);
        status(`Stored locally · ${String(result.chunkCount)} semantic chunks`);
    }
    catch (error) {
        status(String(error), true);
    }
});
void pairingStatus().then((paired) => {
    status(paired ? "Paired · local bridge ready" : "Paste a QR pairing payload");
});
