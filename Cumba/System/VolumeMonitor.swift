import AudioToolbox
import CoreAudio
import Foundation

/// The default output device's volume and mute state, through CoreAudio listeners (no
/// polling, no permission). Also sets them, for the optional volume key handling.
@MainActor
final class VolumeMonitor {
  struct Level: Equatable, Sendable {
    var volume: Float
    var isMuted: Bool
  }

  /// Called on every change of volume, mute or default device.
  var onChange: ((Level) -> Void)?

  private var device = AudioObjectID(kAudioObjectUnknown)
  private var deviceListener: AudioObjectPropertyListenerBlock?
  private var levelListener: AudioObjectPropertyListenerBlock?
  private var isRunning = false

  private static var defaultDeviceAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  private static var volumeAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
    mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
  private static var muteAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyMute,
    mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)

  func start() {
    guard !isRunning else { return }
    isRunning = true
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      MainActor.assumeIsolated { self?.defaultDeviceChanged() }
    }
    deviceListener = listener
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, .main, listener)
    attach(to: Self.defaultOutputDevice())
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    if let deviceListener {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, .main,
        deviceListener)
    }
    deviceListener = nil
    detach()
  }

  var level: Level? {
    guard device != kAudioObjectUnknown, let volume = Self.volume(of: device) else { return nil }
    return Level(volume: volume, isMuted: Self.isMuted(device))
  }

  /// False for outputs macOS can't change the volume of, e.g. some HDMI displays.
  var canSetVolume: Bool {
    var settable = DarwinBoolean(false)
    return device != kAudioObjectUnknown
      && AudioObjectIsPropertySettable(device, &Self.volumeAddress, &settable) == noErr
      && settable.boolValue
  }

  func setVolume(_ volume: Float) {
    var value = min(max(volume, 0), 1)
    AudioObjectSetPropertyData(
      device, &Self.volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    if value > 0, Self.isMuted(device) {
      setMuted(false)
    }
  }

  func setMuted(_ muted: Bool) {
    var value: UInt32 = muted ? 1 : 0
    AudioObjectSetPropertyData(
      device, &Self.muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
  }

  // MARK: - Listening

  private func defaultDeviceChanged() {
    attach(to: Self.defaultOutputDevice())
    if let level {
      onChange?(level)
    }
  }

  private func attach(to newDevice: AudioObjectID) {
    detach()
    device = newDevice
    guard device != kAudioObjectUnknown else { return }
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      MainActor.assumeIsolated {
        guard let self, let level = self.level else { return }
        self.onChange?(level)
      }
    }
    levelListener = listener
    AudioObjectAddPropertyListenerBlock(device, &Self.volumeAddress, .main, listener)
    AudioObjectAddPropertyListenerBlock(device, &Self.muteAddress, .main, listener)
  }

  private func detach() {
    if let levelListener, device != kAudioObjectUnknown {
      AudioObjectRemovePropertyListenerBlock(device, &Self.volumeAddress, .main, levelListener)
      AudioObjectRemovePropertyListenerBlock(device, &Self.muteAddress, .main, levelListener)
    }
    levelListener = nil
    device = AudioObjectID(kAudioObjectUnknown)
  }

  // MARK: - Reading

  private static func defaultOutputDevice() -> AudioObjectID {
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &device)
    return device
  }

  private static func volume(of device: AudioObjectID) -> Float? {
    var volume = Float32(0)
    var size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &volume)
    return status == noErr ? volume : nil
  }

  private static func isMuted(_ device: AudioObjectID) -> Bool {
    var muted = UInt32(0)
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted)
    return status == noErr && muted != 0
  }
}
