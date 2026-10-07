import Cocoa

/// A push, glass, or borderless `NSButton`.
final class ButtonView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let button = NSButton(title: "", target: nil, action: nil)

  override init(frame: NSRect) {
    super.init(frame: frame)
    button.target = self
    button.action = #selector(pressed)
    // Clicks still work, but the Flutter view keeps keyboard focus.
    button.refusesFirstResponder = true
    fill(with: button)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func pressed() { emit?("pressed", nil) }

  func apply(_ p: [String: Any]) {
    let label = p["label"] as? String ?? ""
    button.title = label
    button.image = decodeImage(p["symbol"], label: label)
    button.imagePosition = button.image == nil ? .noImage : (label.isEmpty ? .imageOnly : .imageLeading)
    button.isEnabled = p["enabled"] as? Bool ?? true
    button.controlSize = decodeControlSize(p["controlSize"])
    button.hasDestructiveAction = p["destructive"] as? Bool ?? false

    let style = p["style"] as? String
    button.isBordered = style != "borderless"
    button.bezelStyle = .push
    if style == "automatic", #available(macOS 14.0, *) { button.bezelStyle = .automatic }
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        if style == "glass" { button.bezelStyle = .glass }
        button.tintProminence = decodeProminence(p["prominence"])
        button.borderShape = decodeBorderShape(p["borderShape"])
      }
    #endif

    let tint = decodeColor(p["tint"])
    button.contentTintColor = style == "borderless" ? tint : nil
    button.bezelColor = style == "borderless" ? nil : tint
  }

  func fittingSizeForFlutter() -> NSSize { button.fittingSize }
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
