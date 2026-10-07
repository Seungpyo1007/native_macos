import Cocoa
import FlutterMacOS

/// An AppKit view that Dart configures with a snapshot of all its settings.
protocol NativeControl: NSView {
  /// Sends an event such as `pressed` or `changed` to Dart.
  var emit: ((String, Any?) -> Void)? { get set }

  /// Applies a full snapshot. Calling it again with the same values changes
  /// nothing.
  func apply(_ p: [String: Any])

  /// The size Flutter should give the view, or zero to let Dart decide.
  func fittingSizeForFlutter() -> NSSize

  /// Whether clicks pass through to Flutter, as for glass.
  var passesClicksThrough: Bool { get }
}

extension NativeControl {
  var passesClicksThrough: Bool { false }
}

final class NativeViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let make: () -> NativeControl

  init(messenger: FlutterBinaryMessenger, make: @escaping () -> NativeControl) {
    self.messenger = messenger
    self.make = make
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let p = args as? [String: Any] ?? [:]
    // Dart names the channel so it can listen before the view exists.
    let name = p["channel"] as? String ?? "native_macos/view_native_\(viewId)"
    let host = HostView(control: make(), channel: FlutterMethodChannel(name: name, binaryMessenger: messenger))
    host.update(p)
    return host
  }
}

/// Wraps a control: applies snapshots, reports size changes, and decides
/// whether the control takes clicks.
final class HostView: NSView {
  private let control: NativeControl
  private let channel: FlutterMethodChannel
  private var lastSize = NSSize.zero
  private var interactive = true

  init(control: NativeControl, channel: FlutterMethodChannel) {
    self.control = control
    self.channel = channel
    super.init(frame: .zero)
    control.translatesAutoresizingMaskIntoConstraints = false
    addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.trailingAnchor.constraint(equalTo: trailingAnchor),
      control.topAnchor.constraint(equalTo: topAnchor),
      control.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    control.emit = { [weak self] name, args in
      self?.channel.invokeMethod(name, arguments: args)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      if call.method == "update" {
        self.update(call.arguments as? [String: Any] ?? [:])
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { nil }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func update(_ p: [String: Any]) {
    appearance = NSAppearance(named: p["brightness"] as? String == "dark" ? .darkAqua : .aqua)
    // AppKit does not pass the direction down the view tree.
    setLayoutDirection((p["rtl"] as? Bool ?? false) ? .rightToLeft : .leftToRight, on: self)
    interactive = p["interactive"] as? Bool ?? true
    control.apply(p)
    reportSize()
  }

  /// Sends the fitting size to Dart when it changes.
  func reportSize() {
    let size = control.fittingSizeForFlutter()
    // Sliders and bars have no fitting width; Dart sizes them to the parent.
    guard size.height > 0, size != lastSize else { return }
    lastSize = size
    channel.invokeMethod("size", arguments: ["width": size.width, "height": size.height])
  }

  private func setLayoutDirection(_ direction: NSUserInterfaceLayoutDirection, on view: NSView) {
    view.userInterfaceLayoutDirection = direction
    for child in view.subviews { setLayoutDirection(direction, on: child) }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    if !interactive || control.passesClicksThrough { return nil }
    return super.hitTest(point)
  }
}
