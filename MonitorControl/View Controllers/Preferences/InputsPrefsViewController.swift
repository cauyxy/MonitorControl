//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Settings

/// Built in code: the storyboard can only be compiled with Xcode.
class InputsPrefsViewController: NSViewController, SettingsPane {
  let paneIdentifier = Settings.PaneIdentifier.inputs
  let paneTitle: String = NSLocalizedString("Inputs", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "rectangle.connected.to.line.below", accessibilityDescription: "Inputs")!
    } else {
      return NSImage(named: NSImage.networkName)!
    }
  }

  private let stackView = NSStackView()

  override func loadView() {
    self.stackView.orientation = .vertical
    self.stackView.alignment = .leading
    self.stackView.spacing = 18
    self.stackView.edgeInsets = NSEdgeInsets(top: 20, left: 30, bottom: 20, right: 30)
    self.view = self.stackView
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    self.loadDisplayList()
  }

  func loadDisplayList() {
    guard self.isViewLoaded else {
      return
    }
    for view in self.stackView.arrangedSubviews {
      self.stackView.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    let displays = DisplayManager.shared.getDdcCapableDisplays() + ArrangementManager.shared.hiddenDisplays
    guard !displays.isEmpty else {
      self.stackView.addArrangedSubview(NSTextField(labelWithString: NSLocalizedString("No display with DDC control is connected.", comment: "Shown in the Inputs prefs pane")))
      return
    }
    for display in displays {
      let name = display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name
      let title = NSTextField(labelWithString: name)
      title.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
      let grid = NSGridView(views: [
        [NSTextField(labelWithString: NSLocalizedString("Hide from arrangement unless on:", comment: "Shown in the Inputs prefs pane")), self.arrangementPopUp(display: display)],
        [NSTextField(labelWithString: NSLocalizedString("Show in menu:", comment: "Shown in the Inputs prefs pane")), self.menuSourceCheckboxes(display: display)],
      ])
      grid.column(at: 0).xPlacement = .trailing
      grid.rowAlignment = .firstBaseline
      grid.columnSpacing = 8
      grid.rowSpacing = 8
      let note = NSTextField(wrappingLabelWithString: NSLocalizedString("Set it to the input this Mac is plugged into. While the display shows another input, macOS treats it as disconnected and the menu shows a button to switch back.", comment: "Shown in the Inputs prefs pane"))
      note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
      note.textColor = .secondaryLabelColor
      note.preferredMaxLayoutWidth = 420
      let section = NSStackView(views: [title, grid, note])
      section.orientation = .vertical
      section.alignment = .leading
      section.spacing = 8
      self.stackView.addArrangedSubview(section)
    }
  }

  private func menuSourceCheckboxes(display: OtherDisplay) -> NSView {
    let shown = display.menuInputSources
    let checkboxes: [NSView] = InputSource.allCases.map { source in
      let checkbox = NSButton(checkboxWithTitle: source.title, target: self, action: #selector(self.menuSourceChanged))
      checkbox.state = shown.contains(source) ? .on : .off
      checkbox.identifier = NSUserInterfaceItemIdentifier(display.prefsId)
      checkbox.tag = Int(source.rawValue)
      return checkbox
    }
    let stack = NSStackView(views: checkboxes)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 4
    return stack
  }

  @objc func menuSourceChanged(_ sender: NSButton) {
    guard let prefsId = sender.identifier?.rawValue, let display = ArrangementManager.shared.inputSwitchableDisplay(prefsId: prefsId), let stack = sender.superview as? NSStackView else {
      return
    }
    display.menuInputSources = stack.arrangedSubviews.compactMap { $0 as? NSButton }.filter { $0.state == .on }.compactMap { InputSource(rawValue: UInt16($0.tag)) }
    app.updateMenusAndKeys()
  }

  private func arrangementPopUp(display: OtherDisplay) -> NSPopUpButton {
    let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
    popUp.addItem(withTitle: NSLocalizedString("Never", comment: "Shown in the Inputs prefs pane"))
    for source in InputSource.allCases {
      popUp.addItem(withTitle: source.title)
      popUp.lastItem?.tag = Int(source.rawValue)
    }
    popUp.selectItem(withTag: Int(display.arrangementInputSource?.rawValue ?? 0))
    popUp.identifier = NSUserInterfaceItemIdentifier(display.prefsId)
    popUp.target = self
    popUp.action = #selector(self.arrangementChanged)
    popUp.widthAnchor.constraint(equalToConstant: 150).isActive = true
    return popUp
  }

  @objc func arrangementChanged(_ sender: NSPopUpButton) {
    guard let prefsId = sender.identifier?.rawValue, let display = ArrangementManager.shared.inputSwitchableDisplay(prefsId: prefsId) else {
      return
    }
    display.arrangementInputSource = InputSource(rawValue: UInt16(sender.selectedTag()))
    ArrangementManager.shared.updateArrangementFromCurrentInput(prefsId: prefsId)
  }
}
