//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

/// Standard MCCS values of VCP 0x60 (input select).
enum InputSource: UInt16, CaseIterable {
  case displayPort1 = 15
  case displayPort2 = 16
  case hdmi1 = 17
  case hdmi2 = 18
  case usbC = 27

  static let defaultMenuSources: [InputSource] = [.displayPort1, .hdmi1]

  var title: String {
    switch self {
    case .displayPort1: return "DisplayPort 1"
    case .displayPort2: return "DisplayPort 2"
    case .hdmi1: return "HDMI 1"
    case .hdmi2: return "HDMI 2"
    case .usbC: return "USB-C"
    }
  }

  var shortTitle: String {
    switch self {
    case .displayPort1: return "DP"
    case .displayPort2: return "DP 2"
    case .hdmi1: return "HDMI"
    case .hdmi2: return "HDMI 2"
    case .usbC: return "USB-C"
    }
  }
}
