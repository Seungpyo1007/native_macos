import Cocoa

/// A push, glass, or borderless `NSButton`, or a help or disclosure button.
final class ButtonView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let button = NSButton(title: "", target: nil, action: nil)
  private var kind = "push"
  /// Room around the button for bezels that draw past their frame, such as
  /// the glass bezel's edge highlight.
  private var inset: CGFloat = 0

  override init(frame: NSRect) {
    super.init(frame: frame)
    button.target = self
    button.action = #selector(pressed)
    // Clicks still work, but the Flutter view keeps keyboard focus.
    button.refusesFirstResponder = true
    fill(with: button)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func pressed() {
    if kind == "disclosure" {
      emit?("changed", ["value": button.state == .on])
    } else {
      emit?("pressed", nil)
    }
  }

  func apply(_ p: [String: Any]) {
    kind = p["kind"] as? String ?? "push"
    button.isEnabled = p["enabled"] as? Bool ?? true
    button.controlSize = decodeControlSize(p["controlSize"])
    // Return and Escape reach the button when the Flutter view does not
    // handle them, as for the default and cancel buttons of a dialog.
    button.keyEquivalent = p["isDefault"] as? Bool == true ? "\r" : (p["isCancel"] as? Bool == true ? "\u{1b}" : "")
    inset = 0
    switch kind {
    case "help", "disclosure":
      button.title = ""
      button.image = nil
      button.imagePosition = .noImage
      button.isBordered = true
      button.bezelColor = nil
      button.contentTintColor = nil
      if kind == "help" {
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .helpButton
      } else {
        button.setButtonType(.pushOnPushOff)
        button.bezelStyle = .disclosure
        button.state = p["value"] as? Bool == true ? .on : .off
      }
      needsLayout = true
      return
    default:
      button.setButtonType(.momentaryPushIn)
    }

    let label = p["label"] as? String ?? ""
    button.title = label
    button.image = decodeImage(p["symbol"], label: label)
    button.imagePosition = button.image == nil ? .noImage : (label.isEmpty ? .imageOnly : .imageLeading)
    button.hasDestructiveAction = p["destructive"] as? Bool ?? false

    let style = p["style"] as? String
    button.isBordered = style != "borderless"
    button.bezelStyle = .push
    if style == "automatic", #available(macOS 14.0, *) { button.bezelStyle = .automatic }
    // Before border shapes, an icon-only circle is the circular bezel.
    var circular = p["borderShape"] as? String == "circle" && label.isEmpty && button.image != nil
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { circular = false }
    #endif
    if circular, style != "borderless" { button.bezelStyle = .circular }
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        if style == "glass" {
          button.bezelStyle = .glass
          inset = 3
        }
        button.tintProminence = decodeProminence(p["prominence"])
        button.borderShape = decodeBorderShape(p["borderShape"])
      }
    #endif

    needsLayout = true

    let tint = decodeColor(p["tint"])
    button.contentTintColor = style == "borderless" ? tint : nil
    button.bezelColor = style == "borderless" ? nil : tint
  }

  func fittingSizeForFlutter() -> NSSize {
    let size = button.fittingSize
    return NSSize(width: size.width + inset * 2, height: size.height + inset * 2)
  }

  override func layout() {
    super.layout()
    button.frame = bounds.insetBy(dx: inset, dy: inset)
  }
}

/// An `NSButton` checkbox.
final class CheckboxView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let box = NSButton(checkboxWithTitle: "", target: nil, action: nil)

  override init(frame: NSRect) {
    super.init(frame: frame)
    box.target = self
    box.action = #selector(changed)
    box.refusesFirstResponder = true
    fill(with: box)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() { emit?("changed", ["value": box.state == .on]) }

  func apply(_ p: [String: Any]) {
    box.title = p["label"] as? String ?? ""
    box.state = p["value"] as? Bool == true ? .on : .off
    box.isEnabled = p["enabled"] as? Bool ?? true
    box.controlSize = decodeControlSize(p["controlSize"])
  }

  func fittingSizeForFlutter() -> NSSize { box.fittingSize }
}

/// An `NSSwitch`.
final class SwitchView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let toggle = NSSwitch()

  override init(frame: NSRect) {
    super.init(frame: frame)
    toggle.target = self
    toggle.action = #selector(changed)
    toggle.refusesFirstResponder = true
    fill(with: toggle)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() { emit?("changed", ["value": toggle.state == .on]) }

  func apply(_ p: [String: Any]) {
    toggle.state = p["value"] as? Bool == true ? .on : .off
    toggle.isEnabled = p["enabled"] as? Bool ?? true
    toggle.controlSize = decodeControlSize(p["controlSize"])
  }

  func fittingSizeForFlutter() -> NSSize { toggle.fittingSize }
}

extension NSView {
  /// Adds [view] so it follows this view's bounds.
  func fill(with view: NSView) {
    view.frame = bounds
    view.autoresizingMask = [.width, .height]
    addSubview(view)
  }
}
