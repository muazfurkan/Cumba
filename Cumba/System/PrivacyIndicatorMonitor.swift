import CoreAudio
import CoreMediaIO
import Foundation

/// Reports whether any app is using a microphone or a camera, from the devices' "running
/// somewhere" property. Listeners only, no polling, and no access to audio or video.
@MainActor
final class PrivacyIndicatorMonitor {
  struct State: Equatable, Sendable {
    var microphone = false
    var camera = false
  }

  var onChange: ((State) -> Void)?
  private(set) var state = State()

  private var audioDevices: [AudioObjectID] = []
  private var cameraDevices: [CMIOObjectID] = []
  private var audioListener: AudioObjectPropertyListenerBlock?
  private var cameraListener: CMIOObjectPropertyListenerBlock?
  private var deviceListListener: AudioObjectPropertyListenerBlock?
  private var isRunning = false

  private static var runningAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  private static var devicesAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  private static var cameraRunningAddress = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
  private static var cameraDevicesAddress = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))

  func start() {
    guard !isRunning else { return }
    isRunning = true
    audioListener = { [weak self] _, _ in
      MainActor.assumeIsolated { self?.update() }
    }
    cameraListener = { [weak self] _, _ in
      MainActor.assumeIsolated { self?.update() }
    }
    let listListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      MainActor.assumeIsolated { self?.rescan() }
    }
    deviceListListener = listListener
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &Self.devicesAddress, .main, listListener)
    rescan()
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    if let deviceListListener {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &Self.devicesAddress, .main, deviceListListener)
    }
    deviceListListener = nil
    removeDeviceListeners()
    state = State()
  }

  /// Listens to every input-capable audio device and every camera.
  private func rescan() {
    removeDeviceListeners()
    audioDevices = Self.audioInputDevices()
    cameraDevices = Self.cameras()
    if let audioListener {
      for device in audioDevices {
        AudioObjectAddPropertyListenerBlock(device, &Self.runningAddress, .main, audioListener)
      }
    }
    if let cameraListener {
      for device in cameraDevices {
        CMIOObjectAddPropertyListenerBlock(
          device, &Self.cameraRunningAddress, .main, cameraListener)
      }
    }
    update()
  }

  private func removeDeviceListeners() {
    if let audioListener {
      for device in audioDevices {
        AudioObjectRemovePropertyListenerBlock(device, &Self.runningAddress, .main, audioListener)
      }
    }
    if let cameraListener {
      for device in cameraDevices {
        CMIOObjectRemovePropertyListenerBlock(
          device, &Self.cameraRunningAddress, .main, cameraListener)
      }
    }
    audioDevices = []
    cameraDevices = []
  }

  private func update() {
    let new = State(
      microphone: audioDevices.contains { Self.isRunning(audio: $0) },
      camera: cameraDevices.contains { Self.isRunning(camera: $0) })
    guard new != state else { return }
    state = new
    onChange?(new)
  }

  // MARK: - Devices

  private static func audioInputDevices() -> [AudioObjectID] {
    var size = UInt32(0)
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &devicesAddress, 0, nil, &size) == noErr else {
      return []
    }
    var devices = [AudioObjectID](
      repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &devicesAddress, 0, nil, &size, &devices) == noErr
    else { return [] }
    var streams = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain)
    return devices.filter { device in
      var streamSize = UInt32(0)
      return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamSize) == noErr
        && streamSize > 0
    }
  }

  private static func cameras() -> [CMIOObjectID] {
    var size = UInt32(0)
    let system = CMIOObjectID(kCMIOObjectSystemObject)
    guard CMIOObjectGetPropertyDataSize(system, &cameraDevicesAddress, 0, nil, &size) == noErr
    else { return [] }
    var devices = [CMIOObjectID](
      repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
    var used = UInt32(0)
    guard
      CMIOObjectGetPropertyData(
        system, &cameraDevicesAddress, 0, nil, size, &used, &devices) == noErr
    else { return [] }
    return devices
  }

  private static func isRunning(audio device: AudioObjectID) -> Bool {
    var running = UInt32(0)
    var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &size, &running) == noErr
      && running != 0
  }

  private static func isRunning(camera device: CMIOObjectID) -> Bool {
    var running = UInt32(0)
    var used = UInt32(0)
    return CMIOObjectGetPropertyData(
      device, &cameraRunningAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running)
      == noErr && running != 0
  }
}
