// Saves the port and token for the WebSocket to the Cumba app.
"use strict";

const TR = navigator.language.startsWith("tr");
const TEXT = {
  hint: TR
    ? "Portu ve token'ı Cumba > Ayarlar > Bağlantılar'dan kopyalayın."
    : "Copy the port and token from Cumba > Settings > Connections.",
  port: "Port",
  token: "Token",
  save: TR ? "Kaydet" : "Save",
  saved: TR ? "Kaydedildi." : "Saved.",
  invalid: TR ? "Geçersiz port veya token." : "Invalid port or token.",
  connected: TR ? "Uygulamaya bağlı." : "Connected to the app.",
  connecting: TR ? "Bağlanıyor…" : "Connecting…",
  unreachable: TR ? "Uygulamaya ulaşılamıyor." : "Can't reach the app.",
  disconnected: TR ? "Bağlı değil." : "Not connected.",
  noToken: TR ? "Token girilmedi." : "No token yet.",
};

for (const element of document.querySelectorAll("[data-i18n]")) {
  element.textContent = TEXT[element.dataset.i18n];
}

const port = document.getElementById("port");
const token = document.getElementById("token");
const status = document.getElementById("status");

async function showStatus() {
  try {
    const response = await chrome.runtime.sendMessage({ type: "getStatus" });
    status.textContent = TEXT[response && response.status] || "";
  } catch {
    status.textContent = "";
  }
}

chrome.storage.local.get(["port", "token"]).then((values) => {
  if (values.port) {
    port.value = values.port;
  }
  if (values.token) {
    token.value = values.token;
  }
  showStatus();
});

document.getElementById("save").addEventListener("click", async () => {
  const portValue = Number(port.value);
  const tokenValue = token.value.trim();
  if (!Number.isInteger(portValue) || portValue < 1024 || portValue > 65535
    || !/^[0-9a-f]{64}$/.test(tokenValue)) {
    status.textContent = TEXT.invalid;
    return;
  }
  await chrome.storage.local.set({ port: portValue, token: tokenValue });
  status.textContent = TEXT.saved;
  setTimeout(showStatus, 1500);
});
