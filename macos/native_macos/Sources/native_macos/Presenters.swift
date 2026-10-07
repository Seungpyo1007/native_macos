import Cocoa
import FlutterMacOS

/// Shows `NSAlert`s for `showNativeAlert`.
enum AlertPresenter {
  static func show(_ p: [String: Any], window: NSWindow?, result: @escaping FlutterResult) {
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

    // -1 when the alert closed without a button, such as .abort or .stop.
    let index = { (response: NSApplication.ModalResponse) -> Int in
      let i = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
      return (0..<buttons.count).contains(i) ? i : -1
    }
    if p["asSheet"] as? Bool ?? true, let window {
      alert.beginSheetModal(for: window) { result(index($0)) }
    } else {
      result(index(alert.runModal()))
    }
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
