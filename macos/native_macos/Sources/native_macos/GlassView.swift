import Cocoa

/// `NSGlassEffectView` on macOS 26 and later, `NSVisualEffectView` before.
/// Flutter paints the content on top, so the glass never takes clicks.
final class GlassView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  var passesClicksThrough: Bool { true }
  private var effect: NSView?

  func apply(_ p: [String: Any]) {
    let radius = CGFloat(decodeDouble(p["cornerRadius"]) ?? 16)
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        let glass = (effect as? NSGlassEffectView) ?? install(NSGlassEffectView())
        glass.cornerRadius = radius
        glass.tintColor = decodeColor(p["tint"])
        glass.style = p["style"] as? String == "clear" ? .clear : .regular
        #if compiler(>=6.4)
          if #available(macOS 27.0, *) {
            glass.effectIsInteractive = p["glassInteractive"] as? Bool ?? false
          }
        #endif
        return
      }
    #endif
    let blur = (effect as? NSVisualEffectView) ?? install(NSVisualEffectView())
    blur.material = .popover
    blur.blendingMode = .withinWindow
    blur.state = .active
    blur.wantsLayer = true
    blur.layer?.cornerRadius = radius
    blur.layer?.masksToBounds = true
  }

  private func install<V: NSView>(_ view: V) -> V {
    effect?.removeFromSuperview()
    effect = view
    view.frame = bounds
    view.autoresizingMask = [.width, .height]
    addSubview(view)
    return view
  }

  func fittingSizeForFlutter() -> NSSize { .zero }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
