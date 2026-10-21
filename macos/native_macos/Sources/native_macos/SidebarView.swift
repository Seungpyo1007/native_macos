import Cocoa

/// The background of a sidebar. With the automatic style it is a floating
/// Liquid Glass panel on macOS 26 and later, inset by `inset`; otherwise it
/// is the sidebar material (`NSVisualEffectView.Material.sidebar`), which
/// shows the desktop behind the window.
final class SidebarView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  var passesClicksThrough: Bool { true }
  private var effect: NSView?
  private var inset: CGFloat = 0

  /// Whether the background is drawn with glass.
  var usesGlass: Bool {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { return effect is NSGlassEffectView }
    #endif
    return false
  }

  func apply(_ p: [String: Any]) {
    #if compiler(>=6.2)
      if #available(macOS 26.0, *), p["style"] as? String != "material" {
        let glass = (effect as? NSGlassEffectView) ?? install(NSGlassEffectView())
        glass.cornerRadius = CGFloat(decodeDouble(p["cornerRadius"]) ?? 12)
        glass.tintColor = decodeColor(p["tint"])
        inset = CGFloat(decodeDouble(p["inset"]) ?? 8)
        needsLayout = true
        return
      }
    #endif
    let blur = (effect as? NSVisualEffectView) ?? install(NSVisualEffectView())
    blur.material = .sidebar
    blur.blendingMode = .behindWindow
    blur.state = .followsWindowActiveState
    inset = 0
    needsLayout = true
  }

  private func install<V: NSView>(_ view: V) -> V {
    effect?.removeFromSuperview()
    effect = view
    addSubview(view)
    return view
  }

  override func layout() {
    super.layout()
    effect?.frame = bounds.insetBy(dx: inset, dy: inset)
  }

  func fittingSizeForFlutter() -> NSSize { .zero }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
