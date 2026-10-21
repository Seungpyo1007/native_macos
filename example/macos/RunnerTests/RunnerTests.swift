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

  // MARK: Toolbar

  private func makeToolbar() -> (ToolbarController, NSWindow, () -> [(String, String, Any?)]) {
    var events: [(String, String, Any?)] = []
    let controller = ToolbarController { events.append(($0, $1, $2)) }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: true)
    return (controller, window, { events })
  }

  private let toolbarSpec: [String: Any] = [
    "title": "Mail", "style": "unifiedCompact", "showsTitle": true, "brightness": "dark",
    "items": [
      ["kind": "button", "id": "new", "label": "New", "symbol": "square.and.pencil", "enabled": true],
      ["kind": "segments", "id": "view", "labels": ["A", "B"], "selectedIndex": 1, "enabled": true],
      ["kind": "flexibleSpace"],
      ["kind": "menu", "id": "sort", "label": "Sort", "enabled": true,
       "items": [["title": "Name", "enabled": true], ["divider": true], ["title": "Date", "enabled": true]]],
      ["kind": "search", "id": "search", "placeholder": "Find"],
    ],
  ]

  func testToolbarBuildsItemsOnTheWindow() {
    let (controller, window, _) = makeToolbar()
    controller.set(toolbarSpec, window: window)
    let toolbar = window.toolbar!
    XCTAssertTrue(toolbar === controller.toolbar)
    XCTAssertEqual(window.title, "Mail")
    XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
    XCTAssertEqual(window.appearance?.name, .darkAqua)
    XCTAssertEqual(toolbar.items.count, 5)
    XCTAssertEqual(toolbar.items[2].itemIdentifier, .flexibleSpace)
    XCTAssertEqual((toolbar.items[1] as? NSToolbarItemGroup)?.selectedIndex, 1)
    XCTAssertEqual((toolbar.items[3] as? NSMenuToolbarItem)?.menu.items.count, 3)
    XCTAssertEqual((toolbar.items[4] as? NSSearchToolbarItem)?.searchField.placeholderString, "Find")
  }

  func testToolbarReportsEvents() {
    let (controller, window, events) = makeToolbar()
    controller.set(toolbarSpec, window: window)
    let items = window.toolbar!.items
    controller.buttonPressed(items[0])
    let group = items[1] as! NSToolbarItemGroup
    group.selectedIndex = 0
    controller.segmentChanged(group)
    let date = (items[3] as! NSMenuToolbarItem).menu.items[2]
    controller.menuSelected(date)
    let field = (items[4] as! NSSearchToolbarItem).searchField
    field.stringValue = "hi"
    controller.searchSubmitted(field)
    XCTAssertEqual(events().map(\.0), ["new", "view", "sort", "search"])
    XCTAssertEqual(events().map(\.1), ["pressed", "changed", "selected", "submitted"])
    XCTAssertEqual(events()[2].2 as? Int, 2)
    XCTAssertEqual(events()[3].2 as? String, "hi")
  }

  func testToolbarUpdatesInPlaceAndRebuildsOnStructureChange() {
    let (controller, window, _) = makeToolbar()
    controller.set(toolbarSpec, window: window)
    let first = window.toolbar!.items[0]
    var spec = toolbarSpec
    var items = spec["items"] as! [[String: Any]]
    items[0]["label"] = "Compose"
    items[0]["enabled"] = false
    spec["items"] = items
    controller.set(spec, window: window)
    XCTAssertTrue(window.toolbar!.items[0] === first)
    XCTAssertEqual(first.label, "Compose")
    XCTAssertFalse(first.isEnabled)

    items.removeLast()
    spec["items"] = items
    controller.set(spec, window: window)
    XCTAssertEqual(window.toolbar!.items.count, 4)

    controller.clear(window: window)
    XCTAssertNil(window.toolbar)
    XCTAssertNil(window.appearance)
  }

  func testToolbarKeepsSearchTextWhenItemsBeforeItChange() {
    let (controller, window, _) = makeToolbar()
    controller.set(toolbarSpec, window: window)
    let search = window.toolbar!.items[4] as! NSSearchToolbarItem
    search.searchField.stringValue = "draft"
    var spec = toolbarSpec
    var items = spec["items"] as! [[String: Any]]
    items.removeFirst()
    spec["items"] = items
    controller.set(spec, window: window)
    let rebuilt = window.toolbar!.items.last as! NSSearchToolbarItem
    XCTAssertTrue(rebuilt === search)
    XCTAssertEqual(rebuilt.searchField.stringValue, "draft")
  }

  func testToolbarClearRestoresTheWindow() {
    let (controller, window, _) = makeToolbar()
    window.title = "Original"
    window.toolbarStyle = .expanded
    window.titleVisibility = .visible
    var spec = toolbarSpec
    spec["showsTitle"] = false
    controller.set(spec, window: window)
    XCTAssertEqual(window.title, "Mail")
    XCTAssertEqual(window.titleVisibility, .hidden)
    controller.clear(window: window)
    XCTAssertEqual(window.title, "Original")
    XCTAssertEqual(window.toolbarStyle, .expanded)
    XCTAssertEqual(window.titleVisibility, .visible)
  }

  func testToolbarsDoNotShareAnIdentifier() {
    // AppKit syncs toolbars with the same identifier across windows.
    let (first, firstWindow, _) = makeToolbar()
    let (second, secondWindow, _) = makeToolbar()
    first.set(toolbarSpec, window: firstWindow)
    second.set(toolbarSpec, window: secondWindow)
    XCTAssertNotEqual(first.toolbar!.identifier, second.toolbar!.identifier)
  }

  func testToolbarFromAnotherSessionIsStale() {
    let (controller, window, _) = makeToolbar()
    var spec = toolbarSpec
    spec["session"] = "run1"
    controller.set(spec, window: window)
    XCTAssertFalse(controller.isStale(for: "run1"))
    XCTAssertTrue(controller.isStale(for: "run2"))
    controller.clear(window: window)
    XCTAssertFalse(controller.isStale(for: "run2"))
  }

  // MARK: Hosting

  func testSliderTrackingEndsWithoutAMouseUp() {
    let view = SliderView()
    let events = record(view)
    view.apply(["value": 0.2, "min": 0.0, "max": 1.0, "enabled": true])
    let slider = inner(view, NSSlider.self)
    // A keyboard or VoiceOver change has no mouse event.
    slider.doubleValue = 0.7
    view.changed()
    XCTAssertEqual(events().map(\.0), ["changed", "changeEnded"])
    view.apply(["value": 0.3, "min": 0.0, "max": 1.0, "enabled": true])
    XCTAssertEqual(slider.doubleValue, 0.3, accuracy: 0.0001)
  }

  func testHostViewReportsItsSizeOnlyWhenItChanges() {
    let messenger = FakeMessenger()
    let host = HostView(control: ButtonView(), channel: FlutterMethodChannel(name: "t", binaryMessenger: messenger))
    host.update(["label": "Save", "enabled": true])
    host.update(["label": "Save", "enabled": true])
    XCTAssertEqual(messenger.calls.map(\.method), ["size"])
    host.update(["label": "Save a much longer title", "enabled": true])
    XCTAssertEqual(messenger.calls.map(\.method), ["size", "size"])
    let args = messenger.calls[1].arguments as! [String: Any]
    XCTAssertGreaterThan(args["width"] as! Double, 0)
  }

  func testCapabilitiesMatchTheBuild() {
    var expected = false
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { expected = true }
    #endif
    XCTAssertEqual(NativeMacosPlugin.capabilities()["liquidGlass"] as? Bool, expected)
  }
}

/// Records method calls a view sends to Dart.
private final class FakeMessenger: NSObject, FlutterBinaryMessenger {
  var calls: [FlutterMethodCall] = []

  func send(onChannel channel: String, message: Data?) {
    send(onChannel: channel, message: message, binaryReply: nil)
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {
    if let message {
      calls.append(FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message))
    }
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection { 0 }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
