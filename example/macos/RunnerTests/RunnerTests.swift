import Cocoa
import FlutterMacOS
import XCTest

@testable import native_macos

/// Checks each native control without a Flutter engine: apply a snapshot,
/// read the AppKit properties, and click it.
final class RunnerTests: XCTestCase {
  private func inner<T: NSView>(_ view: NSView, _ type: T.Type) -> T {
    view.subviews.compactMap { $0 as? T }.first!
  }

  private func record(_ control: NativeControl) -> () -> [(String, Any?)] {
    var events: [(String, Any?)] = []
    control.emit = { events.append(($0, $1)) }
    return { events }
  }

  func testButtonAppliesStyleAndReportsPresses() {
    let view = ButtonView()
    let events = record(view)
    view.apply(["label": "Save", "style": "glass", "controlSize": "large", "destructive": true, "enabled": true])
    let button = inner(view, NSButton.self)
    XCTAssertEqual(button.title, "Save")
    XCTAssertEqual(button.controlSize, .large)
    XCTAssertTrue(button.hasDestructiveAction)
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        XCTAssertEqual(button.bezelStyle, .glass)
      }
    #endif
    XCTAssertGreaterThan(view.fittingSizeForFlutter().width, 0)

    button.performClick(nil)
    XCTAssertEqual(events().map(\.0), ["pressed"])
  }

  func testDisabledButtonIgnoresClicks() {
    let view = ButtonView()
    let events = record(view)
    view.apply(["label": "No", "enabled": false])
    inner(view, NSButton.self).performClick(nil)
    XCTAssertTrue(events().isEmpty)
  }

  func testSwitchReportsTheNewValue() {
    let view = SwitchView()
    let events = record(view)
    view.apply(["value": false])
    inner(view, NSSwitch.self).performClick(nil)
    XCTAssertEqual(events().first?.0, "changed")
    XCTAssertEqual((events().first?.1 as? [String: Any])?["value"] as? Bool, true)
  }

  func testCheckboxFollowsTheSnapshot() {
    let view = CheckboxView()
    view.apply(["value": true, "label": "Sync"])
    let box = inner(view, NSButton.self)
    XCTAssertEqual(box.state, .on)
    XCTAssertEqual(box.title, "Sync")
    view.apply(["value": false, "label": "Sync"])
    XCTAssertEqual(box.state, .off)
  }

  func testSegmentedControlBuildsSegments() {
    let view = SegmentedView()
    view.apply(["labels": ["A", "B", "C"], "selectedIndex": 1])
    let control = inner(view, NSSegmentedControl.self)
    XCTAssertEqual(control.segmentCount, 3)
    XCTAssertEqual(control.label(forSegment: 2), "C")
    XCTAssertEqual(control.selectedSegment, 1)
  }

  func testSegmentedControlIgnoresAnOutOfRangeIndex() {
    let view = SegmentedView()
    view.apply(["labels": ["A", "B", "C"], "selectedIndex": 2])
    // Fewer labels while the parent still holds index 2 used to crash.
    view.apply(["labels": ["A", "B"], "selectedIndex": 2])
    XCTAssertEqual(inner(view, NSSegmentedControl.self).selectedSegment, -1)
  }

  func testRightToLeftReachesTheInnerControl() {
    let control = SliderView()
    let host = HostView(control: control, channel: FlutterMethodChannel())
    host.update(["rtl": true])
    XCTAssertEqual(inner(control, NSSlider.self).userInterfaceLayoutDirection, .rightToLeft)
  }

  func testSliderAppliesRangeAndTicks() {
    let view = SliderView()
    view.apply(["value": 5.0, "min": 0.0, "max": 10.0, "tickMarks": 11, "snapToTicks": true])
    let slider = inner(view, NSSlider.self)
    XCTAssertEqual(slider.doubleValue, 5)
    XCTAssertEqual(slider.maxValue, 10)
    XCTAssertEqual(slider.numberOfTickMarks, 11)
    XCTAssertTrue(slider.allowsTickMarkValuesOnly)
  }

  func testPopUpKeepsDividersAndSelects() {
    let view = PopUpButtonView()
    let events = record(view)
    view.apply([
      "items": [["title": "A", "enabled": true], ["divider": true], ["title": "B", "enabled": true]],
      "selectedIndex": 2,
    ])
    let button = inner(view, NSPopUpButton.self)
    XCTAssertEqual(button.numberOfItems, 3)
    XCTAssertTrue(button.item(at: 1)!.isSeparatorItem)
    XCTAssertEqual(button.titleOfSelectedItem, "B")

    button.selectItem(at: 0)
    _ = button.target?.perform(button.action, with: button)
    XCTAssertEqual((events().last?.1 as? [String: Any])?["value"] as? Int, 0)
  }

  func testProgressIsIndeterminateWithoutValue() {
    let view = ProgressView()
    view.apply(["style": "bar"])
    XCTAssertTrue(inner(view, NSProgressIndicator.self).isIndeterminate)
    view.apply(["style": "bar", "value": 0.25])
    let indicator = inner(view, NSProgressIndicator.self)
    XCTAssertFalse(indicator.isIndeterminate)
    XCTAssertEqual(indicator.doubleValue, 0.25)
  }

  func testGlassNeverTakesClicks() {
    let view = GlassView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
    view.apply(["cornerRadius": 12.0])
    XCTAssertNil(view.hitTest(NSPoint(x: 50, y: 20)))
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        XCTAssertEqual(inner(view, NSGlassEffectView.self).cornerRadius, 12)
      }
    #endif
  }

  func testColorDecoding() {
    let color = decodeColor(NSNumber(value: UInt32(0x80FF0000)))!
    XCTAssertEqual(color.redComponent, 1, accuracy: 0.001)
    XCTAssertEqual(color.alphaComponent, 128.0 / 255, accuracy: 0.001)
    XCTAssertNil(decodeColor(nil))
  }
}
