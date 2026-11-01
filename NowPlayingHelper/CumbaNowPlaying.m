// Cumba's Now Playing helper.
//
// macOS answers the private MediaRemote framework (the system's Now Playing, which the media
// keys and Control Center use) only for Apple's own programs. Cumba therefore runs this
// library inside the system's /usr/bin/perl, through Resources/now-playing.pl. It prints one
// JSON line whenever what's playing changes and reads one command per line from stdin:
// toggle, next, previous or "seek <seconds>". It exits when stdin closes, so it never
// outlives Cumba. It reads nothing else and opens no files or network connections.

#import <AppKit/AppKit.h>
#include <dlfcn.h>

typedef void (*CMBGetInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*CMBGetPID)(dispatch_queue_t, void (^)(int));
typedef void (*CMBGetIsPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef void (*CMBRegister)(dispatch_queue_t);
typedef Boolean (*CMBSendCommand)(int, CFDictionaryRef);
typedef void (*CMBSetElapsed)(double);

// MRMediaRemoteCommand values.
enum { CMBTogglePlayPause = 2, CMBNextTrack = 4, CMBPreviousTrack = 5 };

static CMBGetInfo getInfo;
static CMBGetPID getPID;
static CMBGetIsPlaying getIsPlaying;
static CMBSendCommand sendCommand;
static CMBSetElapsed setElapsed;

static NSData *lastReport;
static uint64_t lastArtworkID;
static BOOL updateScheduled;

static id orNull(id value) { return value ?: NSNull.null; }

// JSON has no room for anything else: a live stream reports an infinite duration, and an
// odd player could put anything in these fields.
static id stringOrNull(id value) {
  return [value isKindOfClass:NSString.class] ? value : NSNull.null;
}

static id finiteOrNull(id value) {
  return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) ? value
                                                                               : NSNull.null;
}

// FNV-1a, so changed artwork is sent once instead of with every update.
static uint64_t fingerprint(NSData *data) {
  uint64_t hash = 0xcbf29ce484222325ULL;
  const uint8_t *bytes = data.bytes;
  for (NSUInteger index = 0; index < data.length; index++) {
    hash = (hash ^ bytes[index]) * 0x100000001b3ULL;
  }
  return hash;
}

static void writeLine(NSDictionary *object) {
  if (![NSJSONSerialization isValidJSONObject:object]) return;
  NSData *json = [NSJSONSerialization dataWithJSONObject:object
                                                 options:NSJSONWritingSortedKeys
                                                   error:nil];
  if (!json) return;
  fwrite(json.bytes, 1, json.length, stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

static void report(NSDictionary *info, int pid, BOOL playing) {
  NSMutableDictionary *out = [NSMutableDictionary dictionary];
  NSData *artwork = nil;
  NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
  if ([title isKindOfClass:NSString.class] && title.length > 0) {
    NSRunningApplication *app =
        pid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid] : nil;
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    out[@"bundleID"] = orNull(app.bundleIdentifier);
    out[@"appName"] = orNull(app.localizedName);
    out[@"title"] = title;
    out[@"artist"] = stringOrNull(info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
    out[@"album"] = stringOrNull(info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);
    out[@"duration"] = finiteOrNull(info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
    out[@"elapsed"] = finiteOrNull(info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
    out[@"timestamp"] = [timestamp isKindOfClass:NSDate.class]
                            ? @(timestamp.timeIntervalSince1970)
                            : NSNull.null;
    out[@"playing"] = @(playing);
    artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    if (![artwork isKindOfClass:NSData.class]) artwork = nil;
  }
  uint64_t artworkID = artwork.length > 0 ? fingerprint(artwork) : 0;
  out[@"artworkID"] = [NSString stringWithFormat:@"%016llx", artworkID];
  // Several notifications arrive for one change; report each state once.
  if (![NSJSONSerialization isValidJSONObject:out]) return;
  NSData *comparable = [NSJSONSerialization dataWithJSONObject:out
                                                       options:NSJSONWritingSortedKeys
                                                         error:nil];
  if ([comparable isEqualToData:lastReport]) return;
  lastReport = comparable;
  if (artworkID != 0 && artworkID != lastArtworkID) {
    out[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
  }
  lastArtworkID = artworkID;
  writeLine(out);
}

static void update(void) {
  dispatch_queue_t main = dispatch_get_main_queue();
  getInfo(main, ^(CFDictionaryRef raw) {
    NSDictionary *info = raw ? [(__bridge NSDictionary *)raw copy] : @{};
    getPID(main, ^(int pid) {
      getIsPlaying(main, ^(Boolean playing) {
        report(info, pid, playing);
      });
    });
  });
}

static void scheduleUpdate(void) {
  if (updateScheduled) return;
  updateScheduled = YES;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(),
                 ^{
                   updateScheduled = NO;
                   update();
                 });
}

static void handle(NSString *command) {
  if ([command isEqualToString:@"toggle"]) {
    sendCommand(CMBTogglePlayPause, NULL);
  } else if ([command isEqualToString:@"next"]) {
    sendCommand(CMBNextTrack, NULL);
  } else if ([command isEqualToString:@"previous"]) {
    sendCommand(CMBPreviousTrack, NULL);
  } else if ([command hasPrefix:@"seek "]) {
    double seconds = [command substringFromIndex:5].doubleValue;
    if (seconds >= 0) setElapsed(seconds);
  }
}

// Called by perl through DynaLoader; perl's two arguments are unused. Never returns.
__attribute__((visibility("default"))) void cumba_now_playing_run(void *interpreter, void *cv) {
  void *framework =
      dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
  CMBRegister registerForNotifications =
      framework ? dlsym(framework, "MRMediaRemoteRegisterForNowPlayingNotifications") : NULL;
  getInfo = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingInfo") : NULL;
  getPID = framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationPID") : NULL;
  getIsPlaying =
      framework ? dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") : NULL;
  sendCommand = framework ? dlsym(framework, "MRMediaRemoteSendCommand") : NULL;
  setElapsed = framework ? dlsym(framework, "MRMediaRemoteSetElapsedTime") : NULL;
  if (!registerForNotifications || !getInfo || !getPID || !getIsPlaying || !sendCommand ||
      !setElapsed) {
    writeLine(@{@"error" : @"unavailable"});
    exit(3);
  }

  registerForNotifications(dispatch_get_main_queue());
  for (NSString *name in @[
         @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
         @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
         @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
       ]) {
    [NSNotificationCenter.defaultCenter addObserverForName:name
                                                    object:nil
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *note) {
                                                  scheduleUpdate();
                                                }];
  }
  update();

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    char line[128];
    while (fgets(line, sizeof line, stdin)) {
      NSString *command = [@(line)
          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
      dispatch_async(dispatch_get_main_queue(), ^{
        handle(command);
      });
    }
    exit(0);
  });
  CFRunLoopRun();
  exit(0);
}
