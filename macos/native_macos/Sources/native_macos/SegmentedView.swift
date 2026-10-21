import Cocoa

/// An `NSSegmentedControl` that selects one segment, any number of
/// segments, or acts as momentary buttons.
final class SegmentedView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
  private var labels: [String] = []
  private var symbols: [String] = []

  override init(frame: NSRect) {
    super.init(frame: frame)
    control.target = self
    control.action = #selector(changed)
    control.refusesFirstResponder = true
    fill(with: control)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() {
    switch control.trackingMode {
    case .momentary:
      emit?("pressed", ["value": control.selectedSegment])
    case .selectAny:
      let selected = (0..<control.segmentCount).filter { control.isSelected(forSegment: $0) }
      emit?("changed", ["value": selected])
    default:
      emit?("changed", ["value": control.selectedSegment])
    }
  }

  func apply(_ p: [String: Any]) {
    switch p["mode"] as? String {
    case "momentary": control.trackingMode = .momentary
    case "selectAny": control.trackingMode = .selectAny
    default: control.trackingMode = .selectOne
    }
    let next = p["labels"] as? [String] ?? []
    let nextSymbols = p["symbols"] as? [String] ?? []
    if next != labels || nextSymbols != symbols {
      labels = next
      symbols = nextSymbols
      control.segmentCount = next.count
      for (i, label) in next.enumerated() {
        // A symbol replaces the label, which stays its VoiceOver description.
        let image = nextSymbols[safe: i].flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: label) }
        control.setImage(image, forSegment: i)
        control.setLabel(image == nil ? label : "", forSegment: i)
      }
    }
    let tooltips = p["segmentTooltips"] as? [String] ?? []
    for i in 0..<control.segmentCount { control.setToolTip(tooltips[safe: i], forSegment: i) }
    switch control.trackingMode {
    case .momentary:
      control.selectedSegment = -1
    case .selectAny:
      let selected = Set(p["selected"] as? [Int] ?? [])
      for i in 0..<control.segmentCount { control.setSelected(selected.contains(i), forSegment: i) }
    default:
      // An index past the last segment raises NSRangeException.
      let index = p["selectedIndex"] as? Int ?? -1
      control.selectedSegment = (0..<control.segmentCount).contains(index) ? index : -1
    }
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
