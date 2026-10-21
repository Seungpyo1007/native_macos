import Cocoa
import FlutterMacOS

public class NativeMacosPlugin: NSObject, FlutterPlugin {
  private weak var registrar: FlutterPluginRegistrar?
  private let menus = MenuPresenter()
  private var toolbar: ToolbarController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger
    let controls: [String: () -> NativeControl] = [
      "glass": { GlassView() },
      "button": { ButtonView() },
      "checkbox": { CheckboxView() },
      "switch": { SwitchView() },
      "segmented": { SegmentedView() },
      "slider": { SliderView() },
      "popup": { PopUpButtonView() },
      "progress": { ProgressView() },
    ]
    for (id, make) in controls {
      registrar.register(NativeViewFactory(messenger: messenger, make: make), withId: "native_macos/\(id)")
    }

    let instance = NativeMacosPlugin()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "native_macos", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)

    let toolbarChannel = FlutterMethodChannel(name: "native_macos/toolbar", binaryMessenger: messenger)
    instance.toolbar = ToolbarController(channel: toolbarChannel)
    toolbarChannel.setMethodCallHandler { [weak instance] call, result in
      instance?.handleToolbar(call, result: result) ?? result(nil)
    }
  }

  private func handleToolbar(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let window = registrar?.view?.window
    switch call.method {
    case "set":
      guard let window else { return result(noWindow()) }
      toolbar?.set(call.arguments as? [String: Any] ?? [:], window: window)
      result(nil)
    case "clear":
      toolbar?.clear(window: window)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "capabilities":
      // A new session means a hot restart: the previous run's toolbar has
      // no Dart side left to answer its events.
      if let session = args["session"] as? String, let toolbar, toolbar.isStale(for: session) {
        toolbar.clear(window: registrar?.view?.window)
      }
      result(Self.capabilities())
    case "showAlert":
      let window = registrar?.view?.window
      // An app-modal alert needs no window; only a sheet does.
      if args["asSheet"] as? Bool ?? true, window == nil { return result(noWindow()) }
      AlertPresenter.show(args, window: window, result: result)
    case "showMenu":
      guard let view = registrar?.view, view.window != nil else { return result(noWindow()) }
      menus.show(args, in: view, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// What this build can draw. Glass needs the macOS 26 SDK at build time
  /// and macOS 26 at run time.
  static func capabilities() -> [String: Any] {
    var glass = false
    #if compiler(>=6.2)
      if #available(macOS 26.0, *) { glass = true }
    #endif
    return ["liquidGlass": glass]
  }

  private func noWindow() -> FlutterError {
    FlutterError(code: "no_window", message: "The Flutter view is not in a window yet.", details: nil)
  }
}
