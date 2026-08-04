"use strict";
const api = typeof browser !== "undefined" ? browser : chrome;
api.contextMenus.create({
    id: "archive-highlight",
    title: "Save highlight to ArchiveMe",
    contexts: ["selection"],
});
api.contextMenus.onClicked.addListener((info) => {
    if (info.menuItemId !== "archive-highlight" || !info.selectionText)
        return;
    void api.storage.local.get(["pendingHighlights"]).then((stored) => {
        const current = Array.isArray(stored.pendingHighlights)
            ? stored.pendingHighlights.filter((item) => typeof item === "string")
            : [];
        const next = [...new Set([...current, info.selectionText.trim()])].slice(-256);
        return api.storage.local.set({ pendingHighlights: next });
    });
});
