// Bridges YouTube tabs and the Cumba app over one WebSocket to 127.0.0.1.
// Nothing is sent anywhere else.
"use strict";

const DEFAULT_PORT = 47823;
// Chrome keeps the service worker alive while the socket is active more often than every
// 30 seconds.
const PING_INTERVAL_MS = 20000;
const MAX_BACKOFF_MS = 30000;
const ACTIONS = new Set(["toggle", "play", "pause", "next", "previous", "seek"]);

// Keep the token away from content scripts that run inside YouTube pages.
try {
  chrome.storage.local.setAccessLevel({ accessLevel: "TRUSTED_CONTEXTS" }).catch(() => {});
} catch {
  // Older Chrome: local storage is limited to trusted contexts already.
}

let socket = null;
let backoffMs = 1000;
let reconnectTimer = null;
let pingTimer = null;
let status = "disconnected";
// Latest state per tab, sent again after reconnecting.
const states = new Map();

async function readSettings() {
  const { port = DEFAULT_PORT, token = "" } = await chrome.storage.local.get(["port", "token"]);
  return { port: Number(port) || DEFAULT_PORT, token: String(token) };
}

async function connect() {
  clearTimeout(reconnectTimer);
  if (socket && socket.readyState <= WebSocket.OPEN) {
    return;
  }
  const { port, token } = await readSettings();
  if (!token) {
    status = "noToken";
    return;
  }
  let ws;
  try {
    ws = new WebSocket(`ws://127.0.0.1:${port}/media`);
  } catch {
    scheduleReconnect();
    return;
  }
  socket = ws;
  status = "connecting";
  ws.addEventListener("open", () => {
    backoffMs = 1000;
    status = "connected";
    ws.send(JSON.stringify({ type: "hello", version: 1, token }));
    for (const state of states.values()) {
      ws.send(JSON.stringify(state));
    }
    clearInterval(pingTimer);
    pingTimer = setInterval(() => send({ type: "ping" }), PING_INTERVAL_MS);
  });
  ws.addEventListener("message", (event) => handleCommand(event.data));
  ws.addEventListener("close", () => {
    if (socket !== ws) {
      return;
    }
    socket = null;
    status = status === "connected" ? "disconnected" : "unreachable";
    clearInterval(pingTimer);
    scheduleReconnect();
  });
}

function scheduleReconnect() {
  clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(connect, backoffMs);
  backoffMs = Math.min(backoffMs * 2, MAX_BACKOFF_MS);
}

function send(message) {
  if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(message));
  }
}

function handleCommand(data) {
  let message;
  try {
    message = JSON.parse(data);
  } catch {
    return;
  }
  if (!message || message.type !== "command" || !Number.isInteger(message.tabId)
    || !ACTIONS.has(message.action) || !states.has(message.tabId)) {
    return;
  }
  chrome.tabs
    .sendMessage(message.tabId, {
      type: "command",
      action: message.action,
      position: Number(message.position),
    })
    .catch(() => {});
}

function forget(tabId) {
  if (states.delete(tabId)) {
    send({ type: "closed", tabId });
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) {
    return;
  }
  if (message && message.type === "getStatus") {
    sendResponse({ status });
    return;
  }
  const tabId = sender.tab && sender.tab.id;
  if (tabId === undefined) {
    return;
  }
  if (message && message.type === "state" && message.state) {
    const state = { ...message.state, type: "state", tabId };
    states.set(tabId, state);
    connect();
    send(state);
  } else if (message && message.type === "stopped") {
    forget(tabId);
  }
});

chrome.tabs.onRemoved.addListener((tabId) => forget(tabId));

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && (changes.port || changes.token)) {
    backoffMs = 1000;
    if (socket) {
      const old = socket;
      socket = null;
      old.close();
    }
    connect();
  }
});

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
connect();
