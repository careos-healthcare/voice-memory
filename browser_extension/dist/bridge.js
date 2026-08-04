const api = typeof browser !== "undefined" ? browser : chrome;
const identityStorageKey = "vaultBridgeIdentityV1";
function encode(bytes) {
    const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    let binary = "";
    for (const value of view)
        binary += String.fromCharCode(value);
    return btoa(binary);
}
function decode(value) {
    const binary = atob(value.replace(/-/g, "+").replace(/_/g, "/"));
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    return bytes.buffer;
}
function socketMessage(socket) {
    return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error("Bridge timed out")), 5000);
        socket.addEventListener("message", (event) => {
            clearTimeout(timeout);
            try {
                resolve(JSON.parse(String(event.data)));
            }
            catch (error) {
                reject(error);
            }
        }, { once: true });
        socket.addEventListener("error", () => reject(new Error("Bridge unavailable")), {
            once: true,
        });
    });
}
function openSocket(endpoint) {
    return new Promise((resolve, reject) => {
        const socket = new WebSocket(endpoint);
        socket.addEventListener("open", () => resolve(socket), { once: true });
        socket.addEventListener("error", () => reject(new Error("Bridge unavailable")), {
            once: true,
        });
    });
}
export async function pair(invitation) {
    if (new Date(invitation.expiresAt).getTime() <= Date.now()) {
        throw new Error("Pairing code expired");
    }
    const keys = await crypto.subtle.generateKey("Ed25519", true, [
        "sign",
        "verify",
    ]);
    const publicKey = await crypto.subtle.exportKey("jwk", keys.publicKey);
    const privateKey = await crypto.subtle.exportKey("jwk", keys.privateKey);
    const rawPublicKey = await crypto.subtle.exportKey("raw", keys.publicKey);
    const socket = await openSocket(invitation.endpoint);
    socket.send(JSON.stringify({
        type: "pair",
        token: invitation.token,
        pin: invitation.pin,
        name: navigator.userAgent.includes("Firefox")
            ? "Firefox Web Clipper"
            : "Browser Web Clipper",
        publicKey: encode(rawPublicKey),
    }));
    const response = await socketMessage(socket);
    socket.close();
    if (response.type !== "paired")
        throw new Error(String(response.message));
    const identity = {
        endpoint: invitation.endpoint,
        extensionId: String(response.extensionId),
        sessionKey: String(response.sessionKey),
        publicKey,
        privateKey,
    };
    await api.storage.local.set({ [identityStorageKey]: identity });
}
async function identity() {
    const values = await api.storage.local.get([identityStorageKey]);
    const value = values[identityStorageKey];
    if (!value || typeof value !== "object")
        throw new Error("Browser is not paired");
    return value;
}
export async function clip(payload) {
    const stored = await identity();
    const privateKey = await crypto.subtle.importKey("jwk", stored.privateKey, "Ed25519", false, ["sign"]);
    const socket = await openSocket(stored.endpoint);
    const timestamp = new Date().toISOString();
    const nonceText = encode(crypto.getRandomValues(new Uint8Array(18)));
    const signed = new TextEncoder().encode(`${stored.extensionId}|${timestamp}|${nonceText}`);
    const signature = await crypto.subtle.sign("Ed25519", privateKey, signed);
    socket.send(JSON.stringify({
        type: "hello",
        extensionId: stored.extensionId,
        timestamp,
        nonce: nonceText,
        signature: encode(signature),
    }));
    const ready = await socketMessage(socket);
    if (ready.type !== "ready")
        throw new Error(String(ready.message));
    const sessionKey = await crypto.subtle.importKey("raw", decode(stored.sessionKey), "AES-GCM", false, ["encrypt"]);
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const encrypted = new Uint8Array(await crypto.subtle.encrypt({
        name: "AES-GCM",
        iv: nonce,
        additionalData: new TextEncoder().encode(`browser-clip-v1|${stored.extensionId}`),
        tagLength: 128,
    }, sessionKey, new TextEncoder().encode(JSON.stringify(payload))));
    const ciphertext = encrypted.slice(0, -16);
    const mac = encrypted.slice(-16);
    socket.send(JSON.stringify({
        type: "clip",
        nonce: encode(nonce),
        ciphertext: encode(ciphertext),
        mac: encode(mac),
    }));
    const result = await socketMessage(socket);
    socket.close();
    if (result.type !== "stored")
        throw new Error(String(result.message));
    return result;
}
export async function pairingStatus() {
    try {
        await identity();
        return true;
    }
    catch {
        return false;
    }
}
