import Cocoa

/// An `NSSegmentedControl` that selects one segment.
final class SegmentedView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
  private var labels: [String] = []

  override init(frame: NSRect) {
    super.init(frame: frame)
    control.target = self
    control.action = #selector(changed)
    control.refusesFirstResponder = true
    fill(with: control)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() { emit?("changed", ["value": control.selectedSegment]) }

  func apply(_ p: [String: Any]) {
    let next = p["labels"] as? [String] ?? []
    if next != labels {
      labels = next
      control.segmentCount = next.count
      for (i, label) in next.enumerated() { control.setLabel(label, forSegment: i) }
    }
    // An index past the last segment raises NSRangeException.
    let index = p["selectedIndex"] as? Int ?? -1
    control.selectedSegment = (0..<control.segmentCount).contains(index) ? index : -1
    control.isEnabled = p["enabled"] as? Bool ?? true
    control.controlSize = decodeControlSize(p["controlSize"])
    control.segmentDistribution = p["expand"] as? Bool == true ? .fillEqually : .fit
    control.selectedSegmentBezelColor = decodeColor(p["tint"])
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        control.borderShape = decodeBorderShape(p["borderShape"])
      }
    #endif
  }

  func fittingSizeForFlutter() -> NSSize { control.fittingSize }
}
