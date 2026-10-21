import Cocoa

/// An `NSDatePicker`. Dates travel as milliseconds since the epoch.
final class DatePickerView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let picker = NSDatePicker()

  override init(frame: NSRect) {
    super.init(frame: frame)
    picker.target = self
    picker.action = #selector(changed)
    fill(with: picker)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() {
    emit?("changed", ["value": (picker.dateValue.timeIntervalSince1970 * 1000).rounded()])
  }

  func apply(_ p: [String: Any]) {
    switch p["style"] as? String {
    case "textField": picker.datePickerStyle = .textField
    case "graphical": picker.datePickerStyle = .clockAndCalendar
    default: picker.datePickerStyle = .textFieldAndStepper
    }
    switch p["elements"] as? String {
    case "time": picker.datePickerElements = .hourMinute
    case "dateAndTime": picker.datePickerElements = [.yearMonthDay, .hourMinute]
    default: picker.datePickerElements = .yearMonthDay
    }
    picker.minDate = decodeDate(p["min"])
    picker.maxDate = decodeDate(p["max"])
    if let date = decodeDate(p["value"]), date != picker.dateValue { picker.dateValue = date }
    picker.isEnabled = p["enabled"] as? Bool ?? true
    picker.controlSize = decodeControlSize(p["controlSize"])
  }

  func fittingSizeForFlutter() -> NSSize { picker.fittingSize }
}

/// An `NSStepper`.
final class StepperView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let stepper = NSStepper()

  override init(frame: NSRect) {
    super.init(frame: frame)
    stepper.target = self
    stepper.action = #selector(changed)
    fill(with: stepper)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() { emit?("changed", ["value": stepper.doubleValue]) }

  func apply(_ p: [String: Any]) {
    stepper.minValue = decodeDouble(p["min"]) ?? 0
    stepper.maxValue = decodeDouble(p["max"]) ?? 100
    stepper.increment = decodeDouble(p["step"]) ?? 1
    stepper.valueWraps = p["wraps"] as? Bool ?? false
    stepper.autorepeat = p["autorepeat"] as? Bool ?? true
    stepper.doubleValue = decodeDouble(p["value"]) ?? stepper.minValue
    stepper.isEnabled = p["enabled"] as? Bool ?? true
    stepper.controlSize = decodeControlSize(p["controlSize"])
  }

  func fittingSizeForFlutter() -> NSSize { stepper.fittingSize }
}

/// An `NSColorWell`. Colors travel as sRGB ARGB integers.
final class ColorWellView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let well = NSColorWell()
  private var supportsAlpha = true

  override init(frame: NSRect) {
    super.init(frame: frame)
    well.target = self
    well.action = #selector(changed)
    fill(with: well)
  }

  required init?(coder: NSCoder) { nil }

  deinit {
    // The shared color panel would keep sending colors to a gone well.
    if well.isActive { well.deactivate() }
  }

  @objc private func changed() {
    var color = well.color.usingColorSpace(.sRGB) ?? well.color
    if !supportsAlpha { color = color.withAlphaComponent(1) }
    emit?("changed", ["value": encodeColor(color)])
  }

  func apply(_ p: [String: Any]) {
    supportsAlpha = p["supportsAlpha"] as? Bool ?? true
    if let color = decodeColor(p["value"]), encodeColor(well.color) != encodeColor(color) {
      well.color = color
    }
    well.isEnabled = p["enabled"] as? Bool ?? true
    if #available(macOS 13.0, *) {
      switch p["style"] as? String {
      case "minimal": well.colorWellStyle = .minimal
      case "expanded": well.colorWellStyle = .expanded
      default: well.colorWellStyle = .default
      }
    }
    if #available(macOS 14.0, *) { well.supportsAlpha = supportsAlpha }
  }

  func fittingSizeForFlutter() -> NSSize {
    let size = well.fittingSize
    // Before macOS 13 a well has no intrinsic size.
    return size.width > 0 ? size : NSSize(width: 44, height: 24)
  }
}

func decodeDate(_ v: Any?) -> Date? {
  guard let ms = decodeDouble(v) else { return nil }
  return Date(timeIntervalSince1970: ms / 1000)
}

/// An sRGB color as the ARGB integer Dart's `Color` takes.
func encodeColor(_ color: NSColor) -> Int {
  let c = color.usingColorSpace(.sRGB) ?? color
  func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
  return byte(c.alphaComponent) << 24 | byte(c.redComponent) << 16 | byte(c.greenComponent) << 8
    | byte(c.blueComponent)
}
