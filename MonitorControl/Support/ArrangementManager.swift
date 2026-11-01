//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

/// Input switching and removing displays from the arrangement while they show an input other than the one this Mac is connected to ("Hide from arrangement unless on").
class ArrangementManager {
  static let shared = ArrangementManager()

  /// DDC right after connect or wake often fails, let the link settle first.
  private static let settleDelay: TimeInterval = 2
  /// Input readback lags a few seconds behind a switch, and the link may renegotiate.
  private static let switchSettleTime: TimeInterval = 15
  /// Disabled displays raise no event when the monitor's own OSD switches back, so their input is read at this interval.
  private static let hiddenPollInterval: TimeInterval = 3
  /// Consecutive failed reads after which a hidden display is assumed to be unplugged.
  private static let maxHiddenReadFailures = 5
  private static let maxCheckAttempts = 10

  private(set) var hiddenDisplays: [OtherDisplay] = []
  private var connectedIDs: Set<String> = []
  private var checkSuppressedUntil: [String: Date] = [:]
  private var hiddenReadFailures: [String: Int] = [:]
  private var hiddenPollTimer: Timer?

  /// Online DDC capable display or one removed from the arrangement (those keep their AV service, so DDC still works).
  func inputSwitchableDisplay(prefsId: String) -> OtherDisplay? {
    DisplayManager.shared.getDdcCapableDisplays().first { $0.prefsId == prefsId } ?? self.hiddenDisplays.first { $0.prefsId == prefsId }
  }

  func switchInputSource(display: OtherDisplay, source: InputSource) {
    self.suppressChecks(for: display)
    display.writeInputSource(source.rawValue) { success in
      if success {
        self.updateArrangement(display: display, showing: source.rawValue)
      }
    }
  }

  /// Checks the input of displays with an arrangement input set. Called after reconfiguration (newly connected displays only) and after wake (all displays in the arrangement; hidden ones are polled anyway).
  func checkArrangements(onlyNewlyConnected: Bool) {
    let displays = DisplayManager.shared.getDdcCapableDisplays()
    // A hidden display that is online again was enabled by something else (System Settings, another tool): forget it, it is checked as newly connected below.
    let onlineIDs = Set(displays.map(\.prefsId))
    if self.hiddenDisplays.contains(where: { onlineIDs.contains($0.prefsId) }) {
      self.hiddenDisplays.removeAll { onlineIDs.contains($0.prefsId) }
      self.hiddenDisplaysChanged()
    }
    let previouslyConnected = self.connectedIDs
    self.connectedIDs = onlineIDs
    for display in displays where display.arrangementInputSource != nil && (!onlyNewlyConnected || !previouslyConnected.contains(display.prefsId)) {
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) {
        self.updateArrangementFromCurrentInput(prefsId: display.prefsId)
      }
    }
  }

  func updateArrangementFromCurrentInput(prefsId: String, attempt: Int = 1) {
    guard attempt <= Self.maxCheckAttempts, let display = self.inputSwitchableDisplay(prefsId: prefsId) else {
      return
    }
    guard display.arrangementInputSource != nil else {
      self.updateArrangement(display: display, showing: nil)
      return
    }
    guard (self.checkSuppressedUntil[prefsId] ?? .distantPast) < Date() else {
      return
    }
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.updateArrangementFromCurrentInput(prefsId: prefsId, attempt: attempt + 1) }
      return
    }
    display.readInputSource { current in
      os_log("Arrangement check for display %{public}@ reads input %{public}@", type: .info, prefsId, current.map { String($0) } ?? "nil")
      if let current = current {
        self.updateArrangement(display: display, showing: current)
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.updateArrangementFromCurrentInput(prefsId: prefsId, attempt: attempt + 1) }
      }
    }
  }

  /// Re-enables displays left disabled by a previous run (crash) or before quitting: the disabled state outlives the app.
  func restoreHiddenDisplays() {
    for displayID in prefs.array(forKey: PrefKey.hiddenDisplayIDs.rawValue) as? [Int] ?? [] {
      DisplayConfiguration.setEnabled(CGDirectDisplayID(displayID), enabled: true)
    }
    self.hiddenDisplays.removeAll()
    self.stopPollingIfIdle()
    self.saveHiddenDisplayIDs() // runs at launch and quit, no UI to update
  }

  /// Hides or shows the display depending on whether it shows its arrangement input. `nil` source: no input known, only show.
  private func updateArrangement(display: OtherDisplay, showing source: UInt16?) {
    let macSource = display.arrangementInputSource
    let isHidden = self.hiddenDisplays.contains { $0.prefsId == display.prefsId }
    if isHidden, macSource == nil || source == macSource?.rawValue {
      self.show(display)
    } else if !isHidden, let macSource = macSource, let source = source, source != macSource.rawValue {
      self.hide(display)
    }
  }

  private func hide(_ display: OtherDisplay) {
    var activeDisplayCount: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &activeDisplayCount)
    guard activeDisplayCount > 1 else {
      return // never leave the Mac without a display, for example in clamshell mode
    }
    guard DisplayConfiguration.setEnabled(display.identifier, enabled: false) else {
      return
    }
    self.hiddenDisplays.append(display)
    self.hiddenReadFailures[display.prefsId] = 0
    if self.hiddenPollTimer == nil {
      self.hiddenPollTimer = Timer.scheduledTimer(withTimeInterval: Self.hiddenPollInterval, repeats: true) { _ in self.pollHiddenDisplays() }
    }
    self.hiddenDisplaysChanged()
  }

  private func show(_ display: OtherDisplay, unplugged: Bool = false) {
    self.hiddenDisplays.removeAll { $0.prefsId == display.prefsId }
    if !unplugged {
      self.suppressChecks(for: display)
    }
    DisplayConfiguration.setEnabled(display.identifier, enabled: true)
    self.stopPollingIfIdle()
    self.hiddenDisplaysChanged()
  }

  private func pollHiddenDisplays() {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }
    for display in self.hiddenDisplays {
      display.readInputSource { current in
        guard let current = current else {
          let failures = (self.hiddenReadFailures[display.prefsId] ?? 0) + 1
          self.hiddenReadFailures[display.prefsId] = failures
          if failures >= Self.maxHiddenReadFailures {
            os_log("Hidden display %{public}@ stopped answering DDC, assuming it was unplugged", type: .info, display.prefsId)
            self.show(display, unplugged: true)
          }
          return
        }
        self.hiddenReadFailures[display.prefsId] = 0
        self.updateArrangement(display: display, showing: current)
      }
    }
  }

  /// Don't let a reconnect check act on an input that is still being switched.
  private func suppressChecks(for display: OtherDisplay) {
    self.checkSuppressedUntil[display.prefsId] = Date().addingTimeInterval(Self.switchSettleTime)
  }

  private func stopPollingIfIdle() {
    if self.hiddenDisplays.isEmpty {
      self.hiddenPollTimer?.invalidate()
      self.hiddenPollTimer = nil
    }
  }

  private func saveHiddenDisplayIDs() {
    prefs.set(self.hiddenDisplays.map { Int($0.identifier) }, forKey: PrefKey.hiddenDisplayIDs.rawValue)
  }

  private func hiddenDisplaysChanged() {
    self.saveHiddenDisplayIDs()
    NotificationCenter.default.post(name: .hiddenDisplaysChanged, object: nil)
  }
}

/// Enabling and disabling displays through the private SkyLight call (CGSConfigureDisplayEnabled is not implemented on Apple Silicon).
enum DisplayConfiguration {
  private typealias ConfigureDisplayEnabled = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

  private static let configureDisplayEnabled: ConfigureDisplayEnabled? = {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY), let symbol = dlsym(handle, "SLSConfigureDisplayEnabled") else {
      return nil
    }
    return unsafeBitCast(symbol, to: ConfigureDisplayEnabled.self)
  }()

  @discardableResult static func setEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) -> Bool {
    guard let configureDisplayEnabled = Self.configureDisplayEnabled else {
      return false
    }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else {
      return false
    }
    guard configureDisplayEnabled(config, displayID, enabled) == .success else {
      CGCancelDisplayConfiguration(config)
      return false
    }
    let result = CGCompleteDisplayConfiguration(config, .permanently)
    os_log("Display %{public}@ %{public}@: %{public}@", type: .info, String(displayID), enabled ? "enabled" : "disabled", String(result.rawValue))
    return result == .success
  }
}
