import Cocoa

/// An ARGB integer from Dart's `Color.toARGB32`, or nil.
func decodeColor(_ v: Any?) -> NSColor? {
  guard let n = v as? NSNumber else { return nil }
  let c = n.uint32Value
  return NSColor(
    srgbRed: CGFloat((c >> 16) & 0xFF) / 255,
    green: CGFloat((c >> 8) & 0xFF) / 255,
    blue: CGFloat(c & 0xFF) / 255,
    alpha: CGFloat(c >> 24) / 255)
}

func decodeDouble(_ v: Any?) -> Double? {
  (v as? NSNumber)?.doubleValue
}

func decodeControlSize(_ v: Any?) -> NSControl.ControlSize {
  switch v as? String {
  case "mini": return .mini
  case "small": return .small
  case "large": return .large
  case "extraLarge":
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { return .extraLarge }
    #endif
    return .large
  default: return .regular
  }
}

func decodeImage(_ symbol: Any?, label: String?) -> NSImage? {
  guard let name = symbol as? String else { return nil }
  return NSImage(systemSymbolName: name, accessibilityDescription: label)
}

#if compiler(>=6.2)
  @available(macOS 26.0, *)
  func decodeProminence(_ v: Any?) -> NSTintProminence {
    switch v as? String {
    case "none": return .none
    case "primary": return .primary
    case "secondary": return .secondary
    default: return .automatic
    }
  }

  @available(macOS 26.0, *)
  func decodeBorderShape(_ v: Any?) -> NSControl.BorderShape {
    switch v as? String {
    case "capsule": return .capsule
    case "roundedRectangle": return .roundedRectangle
    case "circle": return .circle
    default: return .automatic
    }
  }
#endif

/// Builds `NSMenuItem`s from Dart's encoded menu entries. Each item's tag is
/// its index in [entries].
func makeMenuItems(_ entries: [[String: Any]], target: AnyObject?, action: Selector?) -> [NSMenuItem] {
  entries.enumerated().map { index, entry in
    if entry["divider"] as? Bool == true { return NSMenuItem.separator() }
    let title = entry["title"] as? String ?? ""
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = target
    item.tag = index
    item.isEnabled = entry["enabled"] as? Bool ?? true
    item.image = decodeImage(entry["symbol"], label: title)
    return item
  }
}
