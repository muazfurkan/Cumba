// Reads the player of a YouTube or YouTube Music tab and applies commands from the app.
// Talks only to this extension's background worker, never to the network.
(() => {
  "use strict";

  const SELECTORS = globalThis.LJASP_SELECTORS;
  const SITE = location.hostname === "music.youtube.com" ? "youtubeMusic" : "youtube";
  // Position is extrapolated by the app; while playing, resend at most every 5 seconds to
  // correct drift.
  const TIMEUPDATE_INTERVAL_MS = 5000;
  // Fallback check for a new <video> element after navigation.
  const VIDEO_CHECK_INTERVAL_MS = 2000;

  let video = null;
  let lastKey = "";
  let lastTimeupdate = 0;

  function isPlayerPage() {
    if (SITE === "youtubeMusic") {
      return true;
    }
    return location.pathname.startsWith("/watch") || location.pathname.startsWith("/shorts/");
  }

  function readMetadata() {
    const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
    const artwork = metadata && metadata.artwork && metadata.artwork.length
      ? metadata.artwork[metadata.artwork.length - 1].src
      : undefined;
    const fallbackTitle = document.title.replace(/ - YouTube( Music)?$/, "");
    return {
      title: (metadata && metadata.title) || fallbackTitle,
      artist: (metadata && metadata.artist) || undefined,
      album: (metadata && metadata.album) || undefined,
      artworkUrl: artwork,
    };
  }

  function send(message) {
    try {
      chrome.runtime.sendMessage(message).catch(() => {});
    } catch {
      // The extension was reloaded; this content script is orphaned.
    }
  }

  function report(force) {
    if (!video || !isPlayerPage()) {
      return;
    }
    const metadata = readMetadata();
    if (!metadata.title) {
      return;
    }
    const state = {
      site: SITE,
      ...metadata,
      videoId: new URLSearchParams(location.search).get("v") || undefined,
      duration: Number.isFinite(video.duration) ? video.duration : undefined,
      position: Number.isFinite(video.currentTime) ? video.currentTime : undefined,
      isPlaying: !video.paused && !video.ended,
      sentAt: Date.now(),
    };
    const key = JSON.stringify({ ...state, position: undefined, sentAt: undefined });
    if (!force && key === lastKey) {
      return;
    }
    lastKey = key;
    send({ type: "state", state });
  }

  function attach(element) {
    if (element === video) {
      return;
    }
    video = element;
    for (const name of ["play", "pause", "ended", "loadedmetadata", "seeked", "ratechange"]) {
      element.addEventListener(name, () => report(true));
    }
    element.addEventListener("timeupdate", () => {
      const now = Date.now();
      if (now - lastTimeupdate >= TIMEUPDATE_INTERVAL_MS) {
        lastTimeupdate = now;
        report(true);
      }
    });
    report(true);
  }

  function findVideo() {
    const element = document.querySelector(SELECTORS.video);
    if (element) {
      attach(element);
    }
  }

  function click(selector) {
    const button = document.querySelector(selector);
    if (button) {
      button.click();
      return true;
    }
    return false;
  }

  function apply(command) {
    if (!video) {
      return;
    }
    switch (command.action) {
      case "toggle":
        video.paused ? video.play().catch(() => {}) : video.pause();
        break;
      case "play":
        video.play().catch(() => {});
        break;
      case "pause":
        video.pause();
        break;
      case "seek":
        if (Number.isFinite(command.position)) {
          const end = Number.isFinite(video.duration) ? video.duration : command.position;
          video.currentTime = Math.min(Math.max(command.position, 0), end);
        }
        break;
      case "next":
        click(SELECTORS[SITE].next);
        break;
      case "previous":
        // Outside playlists there is no previous button; restart the video instead.
        if (!click(SELECTORS[SITE].previous)) {
          video.currentTime = 0;
        }
        break;
    }
  }

  chrome.runtime.onMessage.addListener((message) => {
    if (message && message.type === "command") {
      apply(message);
    }
  });

  // YouTube is a single page app: the title changes on every track or video.
  const title = document.querySelector(SELECTORS.title);
  if (title) {
    new MutationObserver(() => report(false)).observe(title, { childList: true });
  }
  document.addEventListener("yt-navigate-finish", () => {
    findVideo();
    report(true);
  });
  window.addEventListener("pagehide", () => send({ type: "stopped" }));
  setInterval(() => {
    if (!video || !video.isConnected) {
      video = null;
      findVideo();
    }
  }, VIDEO_CHECK_INTERVAL_MS);
  findVideo();
})();
