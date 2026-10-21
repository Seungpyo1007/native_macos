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

/// Builds `NSMenuItem`s from Dart's encoded menu entries, submenus
/// included. Each item's tag is Dart's `tag` for it, or its index in
/// [entries] when there is none. [represented] goes to every item's
/// `representedObject`.
func makeMenuItems(
  _ entries: [[String: Any]], target: AnyObject?, action: Selector?, represented: Any? = nil
) -> [NSMenuItem] {
  entries.enumerated().map { index, entry in
    if entry["divider"] as? Bool == true { return NSMenuItem.separator() }
    let title = entry["title"] as? String ?? ""
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = target
    item.tag = entry["tag"] as? Int ?? index
    item.representedObject = represented
    item.isEnabled = entry["enabled"] as? Bool ?? true
    item.image = decodeImage(entry["symbol"], label: title)
    item.state = entry["checked"] as? Bool == true ? .on : .off
    if let shortcut = entry["shortcut"] as? [String: Any], let key = shortcut["key"] as? String {
      item.keyEquivalent = key
      var mask: NSEvent.ModifierFlags = []
      if shortcut["command"] as? Bool == true { mask.insert(.command) }
      if shortcut["shift"] as? Bool == true { mask.insert(.shift) }
      if shortcut["option"] as? Bool == true { mask.insert(.option) }
      if shortcut["control"] as? Bool == true { mask.insert(.control) }
      item.keyEquivalentModifierMask = mask
    }
    if let children = entry["submenu"] as? [[String: Any]] {
      let submenu = NSMenu(title: title)
      submenu.autoenablesItems = false
      for child in makeMenuItems(children, target: target, action: action, represented: represented) {
        submenu.addItem(child)
      }
      item.submenu = submenu
    }
    return item
  }
}
