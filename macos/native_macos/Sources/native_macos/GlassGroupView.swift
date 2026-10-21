import Cocoa

/// Several glass shapes in one `NSGlassEffectContainerView`, so shapes that
/// come within `spacing` of each other merge and morph. Dart sends each
/// shape's frame in the group's coordinates, top left origin. Before macOS
/// 26 each shape is an `NSVisualEffectView`.
final class GlassGroupView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  var passesClicksThrough: Bool { true }
  private var container: NSView?
  private let canvas = FlippedView()
  /// Shapes by Dart id, kept across updates so a moving shape morphs
  /// instead of being replaced.
  private(set) var shapes: [Int: NSView] = [:]

  func apply(_ p: [String: Any]) {
    let specs = p["shapes"] as? [[String: Any]] ?? []
    let spacing = CGFloat(decodeDouble(p["spacing"]) ?? 0)
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        let group = (container as? NSGlassEffectContainerView) ?? install(NSGlassEffectContainerView())
        group.spacing = spacing
        if group.contentView !== canvas { group.contentView = canvas }
        layoutShapes(specs) { existing in
          let glass = (existing as? NSGlassEffectView) ?? NSGlassEffectView()
          return glass
        } configure: { view, spec in
          guard let glass = view as? NSGlassEffectView else { return }
          glass.cornerRadius = CGFloat(decodeDouble(spec["cornerRadius"]) ?? 16)
          glass.tintColor = decodeColor(spec["tint"])
          glass.style = spec["style"] as? String == "clear" ? .clear : .regular
        }
        return
      }
    #endif
    if container == nil || container?.subviews.first !== canvas {
      let plain = install(NSView())
      canvas.frame = plain.bounds
      canvas.autoresizingMask = [.width, .height]
      plain.addSubview(canvas)
    }
    layoutShapes(specs) { existing in
      (existing as? NSVisualEffectView) ?? NSVisualEffectView()
    } configure: { view, spec in
      guard let blur = view as? NSVisualEffectView else { return }
      blur.material = .popover
      blur.blendingMode = .withinWindow
      blur.state = .active
      blur.wantsLayer = true
      blur.layer?.cornerRadius = CGFloat(decodeDouble(spec["cornerRadius"]) ?? 16)
      blur.layer?.masksToBounds = true
    }
  }

  private func layoutShapes(
    _ specs: [[String: Any]], make: (NSView?) -> NSView, configure: (NSView, [String: Any]) -> Void
  ) {
    var next: [Int: NSView] = [:]
    for spec in specs {
      guard let id = spec["id"] as? Int else { continue }
      let view = make(shapes[id])
      if view.superview !== canvas {
        shapes[id]?.removeFromSuperview()
        canvas.addSubview(view)
      }
      view.frame = NSRect(
        x: decodeDouble(spec["x"]) ?? 0, y: decodeDouble(spec["y"]) ?? 0,
        width: decodeDouble(spec["width"]) ?? 0, height: decodeDouble(spec["height"]) ?? 0)
      configure(view, spec)
      next[id] = view
    }
    for (id, view) in shapes where next[id] == nil { view.removeFromSuperview() }
    shapes = next
  }

  private func install<V: NSView>(_ view: V) -> V {
    container?.removeFromSuperview()
    shapes.values.forEach { $0.removeFromSuperview() }
    shapes = [:]
    container = view
    view.frame = bounds
    view.autoresizingMask = [.width, .height]
    addSubview(view)
    return view
  }

  func fittingSizeForFlutter() -> NSSize { .zero }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A view whose origin is the top left, like Flutter's.
final class FlippedView: NSView {
  override var isFlipped: Bool { true }
}
