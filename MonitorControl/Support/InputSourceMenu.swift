//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit

/// Input source rows of the display blocks in the status menu.
class InputSourceMenu: NSObject {
  private static let rowWidth: CGFloat = 210 // same as the slider rows

  private var controls: [String: NSSegmentedControl] = [:]

  func reset() {
    self.controls.removeAll()
  }

  /// Buttons for the inputs chosen in Settings → Inputs, the current one highlighted.
  func inputRow(display: OtherDisplay) -> NSView {
    let view = NSView(frame: NSRect(x: 0, y: 0, width: Self.rowWidth, height: 32))
    let sources = display.menuInputSources
    let control = NSSegmentedControl(labels: sources.map(\.shortTitle), trackingMode: .selectOne, target: self, action: #selector(self.inputSourceClicked))
    control.controlSize = .small
    control.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    control.segmentDistribution = .fillEqually
    control.frame = NSRect(x: 15, y: 6, width: Self.rowWidth - 30, height: 22)
    control.identifier = NSUserInterfaceItemIdentifier(display.prefsId)
    for (index, source) in sources.enumerated() {
      control.setToolTip(source.title, forSegment: index)
      control.setTag(Int(source.rawValue), forSegment: index)
    }
    self.select(display.lastKnownInputSource, in: control)
    view.addSubview(control)
    self.controls[display.prefsId] = control
    return view
  }

  /// Status and a button switching back to this Mac's input, for a display removed from the arrangement.
  func hiddenDisplayRow(display: OtherDisplay, name: String?) -> NSView {
    let view = NSView(frame: NSRect(x: 0, y: 0, width: Self.rowWidth, height: 58))
    var status = NSLocalizedString("Not in arrangement", comment: "Shown in menu")
    if let name = name {
      status = name + " – " + status
    }
    if let showing = display.lastKnownInputSource.flatMap({ InputSource(rawValue: $0) }) {
      status += " · " + String(format: NSLocalizedString("on %@", comment: "Shown in menu"), showing.shortTitle)
    }
    let label = NSTextField(labelWithString: status)
    label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.lineBreakMode = .byTruncatingTail
    label.frame = NSRect(x: 17, y: 36, width: Self.rowWidth - 32, height: 16)
    view.addSubview(label)
    if let macSource = display.arrangementInputSource {
      let button = NSButton(title: String(format: NSLocalizedString("Switch to %@", comment: "Shown in menu"), macSource.title), target: self, action: #selector(self.switchBackClicked))
      button.bezelStyle = .rounded
      button.identifier = NSUserInterfaceItemIdentifier(display.prefsId)
      button.frame = NSRect(x: 11, y: 2, width: Self.rowWidth - 22, height: 32)
      view.addSubview(button)
    }
    return view
  }

  /// Reads the current inputs, called when the menu opens.
  func refresh() {
    for (prefsId, control) in self.controls {
      guard let display = DisplayManager.shared.getDdcCapableDisplays().first(where: { $0.prefsId == prefsId }) else {
        continue
      }
      display.readInputSource { value in
        if let value = value {
          self.select(value, in: control)
        }
      }
    }
  }

  private func select(_ value: UInt16?, in control: NSSegmentedControl) {
    for segment in 0 ..< control.segmentCount {
      control.setSelected(value.map { control.tag(forSegment: segment) == Int($0) } ?? false, forSegment: segment)
    }
  }

  @objc private func inputSourceClicked(_ sender: NSSegmentedControl) {
    guard let prefsId = sender.identifier?.rawValue, sender.selectedSegment >= 0, let source = InputSource(rawValue: UInt16(sender.tag(forSegment: sender.selectedSegment))), let display = ArrangementManager.shared.inputSwitchableDisplay(prefsId: prefsId) else {
      return
    }
    ArrangementManager.shared.switchInputSource(display: display, source: source)
  }

  @objc private func switchBackClicked(_ sender: NSButton) {
    guard let prefsId = sender.identifier?.rawValue, let display = ArrangementManager.shared.inputSwitchableDisplay(prefsId: prefsId), let source = display.arrangementInputSource else {
      return
    }
    sender.enclosingMenuItem?.menu?.cancelTracking()
    ArrangementManager.shared.switchInputSource(display: display, source: source)
  }
}
