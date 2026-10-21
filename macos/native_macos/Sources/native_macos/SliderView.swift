import Cocoa

/// An `NSSlider` that reports every change and the end of a drag.
final class SliderView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
  /// True during a drag, when updates from Dart lag a frame behind the knob.
  private var tracking = false

  override init(frame: NSRect) {
    super.init(frame: frame)
    slider.target = self
    slider.action = #selector(changed)
    slider.isContinuous = true
    slider.refusesFirstResponder = true
    fill(with: slider)
  }

  required init?(coder: NSCoder) { nil }

  @objc func changed() {
    // Only a mouse drag continues: a mouse up, a key press, VoiceOver, or an
    // action without an event all end the change, so tracking never sticks.
    let type = NSApp?.currentEvent?.type
    let ended = type != .leftMouseDown && type != .leftMouseDragged
    tracking = !ended
    emit?("changed", ["value": slider.doubleValue])
    if ended { emit?("changeEnded", ["value": slider.doubleValue]) }
  }

  func apply(_ p: [String: Any]) {
    slider.minValue = decodeDouble(p["min"]) ?? 0
    slider.maxValue = decodeDouble(p["max"]) ?? 1
    let value = decodeDouble(p["value"]) ?? slider.minValue
    if !tracking, abs(slider.doubleValue - value) > .ulpOfOne { slider.doubleValue = value }
    slider.numberOfTickMarks = p["tickMarks"] as? Int ?? 0
    slider.allowsTickMarkValuesOnly = p["snapToTicks"] as? Bool ?? false
    slider.isEnabled = p["enabled"] as? Bool ?? true
    slider.controlSize = decodeControlSize(p["controlSize"])
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        slider.neutralValue = decodeDouble(p["neutralValue"]) ?? slider.minValue
        slider.tintProminence = decodeProminence(p["prominence"])
      }
    #endif
  }

  func fittingSizeForFlutter() -> NSSize { slider.fittingSize }
}
