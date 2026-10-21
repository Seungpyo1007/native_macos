import Cocoa
import FlutterMacOS

/// Shows `NSAlert`s for `showNativeAlert`.
enum AlertPresenter {
  static func show(_ p: [String: Any], window: NSWindow?, result: @escaping FlutterResult) {
    let (alert, field) = build(p)
    let buttons = p["buttons"] as? [[String: Any]] ?? []

    // -1 when the alert closed without a button, such as .abort or .stop.
    let detailed = p["detailed"] as? Bool ?? false
    let answer = { (response: NSApplication.ModalResponse) -> Any in
      let i = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
      let index = (0..<buttons.count).contains(i) ? i : -1
      guard detailed else { return index }
      var reply: [String: Any] = ["index": index, "suppressed": alert.suppressionButton?.state == .on]
      if let field { reply["text"] = field.stringValue }
      return reply
    }
    if p["asSheet"] as? Bool ?? true, let window {
      alert.beginSheetModal(for: window) { result(answer($0)) }
    } else {
      result(answer(alert.runModal()))
    }
  }

  /// The alert for [p], and its text field when it has one.
  static func build(_ p: [String: Any]) -> (NSAlert, NSTextField?) {
    let alert = NSAlert()
    alert.messageText = p["title"] as? String ?? ""
    alert.informativeText = p["message"] as? String ?? ""
    switch p["style"] as? String {
    case "informational": alert.alertStyle = .informational
    case "critical": alert.alertStyle = .critical
    default: alert.alertStyle = .warning
    }
    alert.window.appearance = NSAppearance(named: p["brightness"] as? String == "dark" ? .darkAqua : .aqua)

    let buttons = p["buttons"] as? [[String: Any]] ?? []
    let hasDefault = buttons.contains { $0["isDefault"] as? Bool == true }
    let hasCancel = buttons.contains { $0["isCancel"] as? Bool == true }
    for spec in buttons {
      let button = alert.addButton(withTitle: spec["title"] as? String ?? "")
      button.hasDestructiveAction = spec["destructive"] as? Bool ?? false
      if hasCancel {
        // AppKit guesses Escape from titles such as "Cancel"; Dart says.
        if spec["isCancel"] as? Bool == true {
          button.keyEquivalent = "\u{1b}"
        } else if button.keyEquivalent == "\u{1b}" {
          button.keyEquivalent = ""
        }
      }
      if hasDefault {
        // AppKit gives Return to the first button; move it to the chosen one.
        if spec["isDefault"] as? Bool == true {
          button.keyEquivalent = "\r"
        } else if button.keyEquivalent == "\r" {
          button.keyEquivalent = ""
        }
      }
    }

    if let label = p["suppressionLabel"] as? String {
      alert.showsSuppressionButton = true
      alert.suppressionButton?.title = label
      alert.suppressionButton?.state = p["suppressed"] as? Bool == true ? .on : .off
    }
    var field: NSTextField?
    if let spec = p["textField"] as? [String: Any] {
      let input = spec["secure"] as? Bool == true ? NSSecureTextField() : NSTextField()
      input.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
      input.stringValue = spec["text"] as? String ?? ""
      input.placeholderString = spec["placeholder"] as? String
      alert.accessoryView = input
      // The field takes the keys first, so typing goes straight into it.
      alert.layout()
      alert.window.initialFirstResponder = input
      field = input
    }
    return (alert, field)
  }
}

/// Shows an `NSPopover` with a title, a message, and buttons next to a rect
/// of the Flutter view, for `showNativePopover`. One popover at a time: a
/// new one closes the previous, which answers nil.
final class PopoverPresenter: NSObject, NSPopoverDelegate {
  private(set) var popover: NSPopover?
  private var pending: FlutterResult?
  private var chosen: Int?

  func show(_ p: [String: Any], in view: NSView, result: @escaping FlutterResult) {
    popover?.close()
    finish()

    let content = NSStackView()
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 8
    content.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
    let rtl = p["rtl"] as? Bool == true
    content.userInterfaceLayoutDirection = rtl ? .rightToLeft : .leftToRight
    let maxWidth = CGFloat(decodeDouble(p["maxWidth"]) ?? 280)
    if let title = p["title"] as? String {
      let label = NSTextField(wrappingLabelWithString: title)
      label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
      label.preferredMaxLayoutWidth = maxWidth
      content.addArrangedSubview(label)
    }
    if let message = p["message"] as? String {
      let label = NSTextField(wrappingLabelWithString: message)
      label.preferredMaxLayoutWidth = maxWidth
      content.addArrangedSubview(label)
    }
    let actions = p["actions"] as? [[String: Any]] ?? []
    if !actions.isEmpty {
      let row = NSStackView()
      row.orientation = .horizontal
      row.spacing = 8
      for (i, spec) in actions.enumerated() {
        let button = NSButton(title: spec["title"] as? String ?? "", target: self, action: #selector(pressed(_:)))
        button.tag = i
        button.hasDestructiveAction = spec["destructive"] as? Bool ?? false
        if spec["isDefault"] as? Bool == true { button.keyEquivalent = "\r" }
        row.addArrangedSubview(button)
      }
      content.addArrangedSubview(row)
    }

    let controller = NSViewController()
    controller.view = content
    let popover = NSPopover()
    popover.contentViewController = controller
    popover.behavior = .transient
    popover.animates = p["animates"] as? Bool ?? true
    popover.delegate = self
    popover.appearance = NSAppearance(named: p["brightness"] as? String == "dark" ? .darkAqua : .aqua)
    self.popover = popover
    pending = result
    chosen = nil

    // Flutter's origin is the top left; AppKit's is the bottom left unless
    // the view is flipped.
    let x = CGFloat(decodeDouble(p["x"]) ?? 0)
    let y = CGFloat(decodeDouble(p["y"]) ?? 0)
    let width = CGFloat(decodeDouble(p["width"]) ?? 0)
    let height = CGFloat(decodeDouble(p["height"]) ?? 0)
    let rect = NSRect(x: x, y: view.isFlipped ? y : view.bounds.height - y - height, width: width, height: height)
    popover.show(relativeTo: rect, of: view, preferredEdge: Self.edge(p["edge"] as? String, flipped: view.isFlipped, rtl: rtl))
  }

  /// The AppKit edge for Dart's [edge], in the view's coordinates.
  static func edge(_ edge: String?, flipped: Bool, rtl: Bool) -> NSRectEdge {
    switch edge {
    case "top": return flipped ? .minY : .maxY
    case "leading": return rtl ? .maxX : .minX
    case "trailing": return rtl ? .minX : .maxX
    default: return flipped ? .maxY : .minY
    }
  }

  @objc private func pressed(_ sender: NSButton) {
    chosen = sender.tag
    popover?.close()
  }

  func popoverDidClose(_ notification: Notification) {
    if (notification.object as? NSPopover) === popover { finish() }
  }

  private func finish() {
    let result = pending
    pending = nil
    popover = nil
    result?(chosen)
    chosen = nil
  }
}

/// Window and title bar settings for `NativeWindow.configure`.
enum WindowConfigurator {
  static func apply(_ p: [String: Any], to window: NSWindow) {
    if let subtitle = p["subtitle"] as? String { window.subtitle = subtitle }
    if let full = p["fullSizeContent"] as? Bool {
      if full { window.styleMask.insert(.fullSizeContentView) } else { window.styleMask.remove(.fullSizeContentView) }
    }
    if let transparent = p["transparentTitlebar"] as? Bool { window.titlebarAppearsTransparent = transparent }
    switch p["separator"] as? String {
    case "none": window.titlebarSeparatorStyle = .none
    case "line": window.titlebarSeparatorStyle = .line
    case "shadow": window.titlebarSeparatorStyle = .shadow
    case "automatic": window.titlebarSeparatorStyle = .automatic
    default: break
    }
  }

  /// The title bar height, toolbar included, that full-size content goes
  /// under.
  static func metrics(of window: NSWindow) -> [String: Any] {
    let titlebar = max(0, window.frame.height - window.contentLayoutRect.height)
    return ["titlebarHeight": titlebar, "fullSizeContent": window.styleMask.contains(.fullSizeContentView)]
  }
}

/// Pops up `NSMenu`s for `showNativeMenu`.
final class MenuPresenter: NSObject {
  private var chosen: Int?

  func show(_ p: [String: Any], in view: NSView, result: @escaping FlutterResult) {
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.appearance = NSAppearance(named: p["brightness"] as? String == "dark" ? .darkAqua : .aqua)
    menu.userInterfaceLayoutDirection = p["rtl"] as? Bool == true ? .rightToLeft : .leftToRight
    let entries = p["items"] as? [[String: Any]] ?? []
    for item in makeMenuItems(entries, target: self, action: #selector(choose(_:))) {
      menu.addItem(item)
    }
    // Flutter's origin is the top left; AppKit's is the bottom left unless
    // the view is flipped.
    let x = CGFloat(decodeDouble(p["x"]) ?? 0)
    let y = CGFloat(decodeDouble(p["y"]) ?? 0)
    let point = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
    chosen = nil
    menu.popUp(positioning: nil, at: point, in: view)
    result(chosen)
  }

  @objc private func choose(_ item: NSMenuItem) { chosen = item.tag }
}
