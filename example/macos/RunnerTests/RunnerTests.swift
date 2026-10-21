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

  // MARK: 0.3.0

  func testHostAppliesTooltipLabelAndFocus() {
    let control = ButtonView()
    let host = HostView(control: control, channel: FlutterMethodChannel(name: "a", binaryMessenger: FakeMessenger()))
    let button = inner(control, NSButton.self)
    XCTAssertTrue(button.refusesFirstResponder)
    host.update(["label": "", "symbol": "trash", "tooltip": "Delete", "semanticsLabel": "Delete item", "focusable": true])
    XCTAssertEqual(button.toolTip, "Delete")
    XCTAssertEqual(button.accessibilityLabel(), "Delete item")
    XCTAssertFalse(button.refusesFirstResponder)
    host.update(["label": "Save"])
    XCTAssertNil(button.toolTip)
    XCTAssertTrue(button.refusesFirstResponder)
    XCTAssertNotEqual(button.accessibilityLabel(), "Delete item")
  }

  func testGlassViewsHaveNoAccessibilityTarget() {
    XCTAssertNil(GlassView().accessibilityTarget)
    XCTAssertNil(GlassGroupView().accessibilityTarget)
    XCTAssertNil(SidebarView().accessibilityTarget)
  }

  func testHelpAndDisclosureButtons() {
    let help = ButtonView()
    let helpEvents = record(help)
    help.apply(["kind": "help", "enabled": true])
    let helpButton = inner(help, NSButton.self)
    XCTAssertEqual(helpButton.bezelStyle, .helpButton)
    helpButton.performClick(nil)
    XCTAssertEqual(helpEvents().map(\.0), ["pressed"])

    let disclosure = ButtonView()
    let events = record(disclosure)
    disclosure.apply(["kind": "disclosure", "value": false, "enabled": true])
    let triangle = inner(disclosure, NSButton.self)
    XCTAssertEqual(triangle.bezelStyle, .disclosure)
    triangle.performClick(nil)
    XCTAssertEqual(events().first?.0, "changed")
    XCTAssertEqual((events().first?.1 as? [String: Any])?["value"] as? Bool, true)
  }

  func testDefaultAndCancelButtonsTakeReturnAndEscape() {
    let view = ButtonView()
    view.apply(["label": "OK", "isDefault": true])
    XCTAssertEqual(inner(view, NSButton.self).keyEquivalent, "\r")
    view.apply(["label": "Cancel", "isCancel": true])
    XCTAssertEqual(inner(view, NSButton.self).keyEquivalent, "\u{1b}")
    view.apply(["label": "Plain"])
    XCTAssertEqual(inner(view, NSButton.self).keyEquivalent, "")
  }

  func testSegmentedModesAndSymbols() {
    let momentary = SegmentedView()
    let pressed = record(momentary)
    momentary.apply(["mode": "momentary", "labels": ["Back", "Forward"], "symbols": ["chevron.left", "chevron.right"],
                     "segmentTooltips": ["Go back", "Go forward"]])
    let control = inner(momentary, NSSegmentedControl.self)
    XCTAssertEqual(control.trackingMode, .momentary)
    XCTAssertNotNil(control.image(forSegment: 0))
    XCTAssertEqual(control.label(forSegment: 0), "")
    XCTAssertEqual(control.toolTip(forSegment: 1), "Go forward")
    // A momentary control keeps no selection, so only a real click reports
    // the segment; the action without one reports none.
    _ = control.target?.perform(control.action, with: control)
    XCTAssertEqual(pressed().first?.0, "pressed")

    let multi = SegmentedView()
    let changed = record(multi)
    multi.apply(["mode": "selectAny", "labels": ["B", "I", "U"], "selected": [0, 2]])
    let any = inner(multi, NSSegmentedControl.self)
    XCTAssertTrue(any.isSelected(forSegment: 0))
    XCTAssertFalse(any.isSelected(forSegment: 1))
    XCTAssertTrue(any.isSelected(forSegment: 2))
    any.setSelected(true, forSegment: 1)
    _ = any.target?.perform(any.action, with: any)
    XCTAssertEqual((changed().first?.1 as? [String: Any])?["value"] as? [Int], [0, 1, 2])
  }

  func testMenuItemsHaveSubmenusChecksAndShortcuts() {
    let items = makeMenuItems(
      [
        ["tag": 0, "title": "Copy", "enabled": true, "checked": true,
         "shortcut": ["key": "c", "command": true, "shift": true]],
        ["tag": 1, "title": "Sort", "enabled": true, "submenu": [
          ["tag": 2, "title": "Name", "enabled": true], ["tag": 3, "divider": true], ["tag": 4, "title": "Size", "enabled": true],
        ]],
      ], target: nil, action: #selector(NSObject.description), represented: "menu")
    XCTAssertEqual(items[0].state, .on)
    XCTAssertEqual(items[0].keyEquivalent, "c")
    XCTAssertEqual(items[0].keyEquivalentModifierMask, [.command, .shift])
    let sub = items[1].submenu!
    XCTAssertEqual(sub.items.map(\.tag), [2, 0, 4])
    XCTAssertTrue(sub.items[1].isSeparatorItem)
    XCTAssertEqual(sub.items[2].representedObject as? String, "menu")
  }

  func testGlassGroupKeepsShapesById() {
    let view = GlassGroupView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
    let shape: (Int, Double) -> [String: Any] = { id, x in
      ["id": id, "x": x, "y": 10.0, "width": 40.0, "height": 30.0, "cornerRadius": 15.0]
    }
    view.apply(["spacing": 12.0, "shapes": [shape(0, 10), shape(1, 60)]])
    XCTAssertEqual(view.shapes.count, 2)
    let first = view.shapes[0]!
    // A move keeps the same view, which is what lets glass morph.
    view.apply(["spacing": 12.0, "shapes": [shape(0, 30)]])
    XCTAssertTrue(view.shapes[0] === first)
    XCTAssertNil(view.shapes[1])
    XCTAssertEqual(first.frame, NSRect(x: 30, y: 10, width: 40, height: 30))
    XCTAssertTrue(first.superview?.isFlipped ?? false)
    XCTAssertNil(view.hitTest(NSPoint(x: 40, y: 20)))
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        XCTAssertTrue(first is NSGlassEffectView)
        XCTAssertEqual((view.subviews.first as? NSGlassEffectContainerView)?.spacing, 12)
      }
    #endif
  }

  func testSidebarUsesGlassOnlyWhenAutomatic() {
    let view = SidebarView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
    view.apply(["style": "material"])
    XCTAssertFalse(view.usesGlass)
    XCTAssertEqual((view.subviews.first as? NSVisualEffectView)?.material, .sidebar)
    view.apply(["style": "automatic", "inset": 8.0])
    var expected = false
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { expected = true }
    #endif
    XCTAssertEqual(view.usesGlass, expected)
    view.layout()
    XCTAssertEqual(view.subviews.first?.frame.minX, expected ? 8 : 0)
  }

  func testDatePickerRoundTripsMilliseconds() {
    let view = DatePickerView()
    let events = record(view)
    let ms = 1_790_000_000_000.0
    view.apply(["value": ms, "style": "graphical", "elements": "dateAndTime", "enabled": true])
    let picker = inner(view, NSDatePicker.self)
    XCTAssertEqual(picker.datePickerStyle, .clockAndCalendar)
    XCTAssertEqual(picker.datePickerElements, [.yearMonthDay, .hourMinute])
    XCTAssertEqual(picker.dateValue.timeIntervalSince1970 * 1000, ms, accuracy: 1)
    picker.dateValue = Date(timeIntervalSince1970: 1_790_000_060)
    _ = picker.target?.perform(picker.action, with: picker)
    XCTAssertEqual((events().first?.1 as? [String: Any])?["value"] as? Double, 1_790_000_060_000)
  }

  func testStepperAppliesRangeAndReports() {
    let view = StepperView()
    let events = record(view)
    view.apply(["value": 4.0, "min": 0.0, "max": 5.0, "step": 1.0, "wraps": true, "enabled": true])
    let stepper = inner(view, NSStepper.self)
    XCTAssertEqual(stepper.doubleValue, 4)
    XCTAssertTrue(stepper.valueWraps)
    stepper.doubleValue = 5
    _ = stepper.target?.perform(stepper.action, with: stepper)
    XCTAssertEqual((events().first?.1 as? [String: Any])?["value"] as? Double, 5)
  }

  func testColorWellUsesSRGB() {
    let view = ColorWellView()
    let events = record(view)
    view.apply(["value": NSNumber(value: UInt32(0xFF336699)), "supportsAlpha": false, "enabled": true])
    let well = inner(view, NSColorWell.self)
    XCTAssertEqual(encodeColor(well.color), 0xFF336699)
    well.color = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 0.5)
    _ = well.target?.perform(well.action, with: well)
    // Without alpha the reported color is opaque.
    XCTAssertEqual((events().first?.1 as? [String: Any])?["value"] as? Int, 0xFFFF0000)
  }

  func testPopoverEdgesFollowFlippingAndDirection() {
    XCTAssertEqual(PopoverPresenter.edge("bottom", flipped: false, rtl: false), .minY)
    XCTAssertEqual(PopoverPresenter.edge("bottom", flipped: true, rtl: false), .maxY)
    XCTAssertEqual(PopoverPresenter.edge("top", flipped: false, rtl: false), .maxY)
    XCTAssertEqual(PopoverPresenter.edge("leading", flipped: false, rtl: true), .maxX)
    XCTAssertEqual(PopoverPresenter.edge("trailing", flipped: false, rtl: false), .maxX)
  }

  func testWindowConfiguratorChangesTheTitleBar() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled, .closable], backing: .buffered,
      defer: true)
    WindowConfigurator.apply(
      ["subtitle": "3 items", "fullSizeContent": true, "transparentTitlebar": true, "separator": "none"], to: window)
    XCTAssertEqual(window.subtitle, "3 items")
    XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
    XCTAssertTrue(window.titlebarAppearsTransparent)
    XCTAssertEqual(window.titlebarSeparatorStyle, .none)
    let metrics = WindowConfigurator.metrics(of: window)
    XCTAssertGreaterThan(metrics["titlebarHeight"] as! CGFloat, 0)
    XCTAssertEqual(metrics["fullSizeContent"] as? Bool, true)
    // Missing keys leave the window alone.
    WindowConfigurator.apply([:], to: window)
    XCTAssertEqual(window.subtitle, "3 items")
  }

  func testToolbarDisplayModeTooltipsAndSearchText() {
    let (controller, window, events) = makeToolbar()
    var spec = toolbarSpec
    // Labels show only with the expanded style; unified styles keep icons.
    spec["style"] = "expanded"
    spec["displayMode"] = "iconAndLabel"
    spec["rtl"] = true
    var items = spec["items"] as! [[String: Any]]
    items[1]["tooltips"] = ["First", "Second"]
    spec["items"] = items
    controller.set(spec, window: window)
    let toolbar = window.toolbar!
    XCTAssertEqual(toolbar.displayMode, .iconAndLabel)
    XCTAssertEqual((toolbar.items[1] as! NSToolbarItemGroup).subitems[1].toolTip, "Second")
    let search = toolbar.items[4] as! NSSearchToolbarItem
    XCTAssertEqual(search.searchField.baseWritingDirection, .rightToLeft)
    XCTAssertEqual((toolbar.items[3] as! NSMenuToolbarItem).menu.userInterfaceLayoutDirection, .rightToLeft)

    XCTAssertTrue(controller.setSearchText("inbox", id: "search"))
    XCTAssertEqual(search.searchField.stringValue, "inbox")
    XCTAssertEqual(controller.searchText(id: "search"), "inbox")
    XCTAssertFalse(controller.setSearchText("x", id: "missing"))
    // Setting from Dart does not report a change back.
    XCTAssertTrue(events().isEmpty)
  }

  func testAlertAddsSuppressionAndTextField() {
    let (alert, field) = AlertPresenter.build([
      "title": "Sign in", "buttons": [["title": "OK", "isDefault": true], ["title": "Cancel", "isCancel": true]],
      "suppressionLabel": "Remember me", "suppressed": true,
      "textField": ["text": "me", "placeholder": "Password", "secure": true],
    ])
    XCTAssertTrue(alert.showsSuppressionButton)
    XCTAssertEqual(alert.suppressionButton?.title, "Remember me")
    XCTAssertEqual(alert.suppressionButton?.state, .on)
    XCTAssertTrue(field is NSSecureTextField)
    XCTAssertEqual(field?.stringValue, "me")
    XCTAssertTrue(alert.accessoryView === field)
    XCTAssertEqual(alert.buttons.map(\.keyEquivalent), ["\r", "\u{1b}"])
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
