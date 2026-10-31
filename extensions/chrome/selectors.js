// Every DOM selector the extension uses, in one place. When YouTube changes its markup,
// only this file needs an update.
globalThis.CUMBA_SELECTORS = Object.freeze({
  video: "video.html5-main-video, ytmusic-player video, video",
  title: "title",
  youtube: Object.freeze({
    next: ".ytp-next-button",
    previous: ".ytp-prev-button",
  }),
  youtubeMusic: Object.freeze({
    next: "ytmusic-player-bar .next-button",
    previous: "ytmusic-player-bar .previous-button",
  }),
});
