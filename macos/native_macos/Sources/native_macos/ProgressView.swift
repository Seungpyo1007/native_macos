import Cocoa

/// A bar or spinning `NSProgressIndicator`. A missing value is indeterminate.
final class ProgressView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let indicator = NSProgressIndicator()

  override init(frame: NSRect) {
    super.init(frame: frame)
    indicator.minValue = 0
    indicator.maxValue = 1
    fill(with: indicator)
  }

  required init?(coder: NSCoder) { nil }

  func apply(_ p: [String: Any]) {
    indicator.style = p["style"] as? String == "spinning" ? .spinning : .bar
    indicator.controlSize = decodeControlSize(p["controlSize"])
    if let value = decodeDouble(p["value"]) {
      indicator.isIndeterminate = false
      indicator.stopAnimation(nil)
      indicator.doubleValue = value
    } else {
      indicator.isIndeterminate = true
      indicator.startAnimation(nil)
    }
  }

  func fittingSizeForFlutter() -> NSSize { indicator.fittingSize }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    // Flutter takes the view out of the window whenever it is not painted,
    // such as under an opaque route, and puts it back later.
    if window == nil {
      indicator.stopAnimation(nil)
    } else if indicator.isIndeterminate {
      indicator.startAnimation(nil)
    }
  }
}
