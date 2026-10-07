import Cocoa
import FlutterMacOS

public class NativeMacosPlugin: NSObject, FlutterPlugin {
  private weak var registrar: FlutterPluginRegistrar?
  private let menus = MenuPresenter()

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
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "showAlert":
      guard let window = registrar?.view?.window else { return result(noWindow()) }
      AlertPresenter.show(args, window: window, result: result)
    case "showMenu":
      guard let view = registrar?.view, view.window != nil else { return result(noWindow()) }
      menus.show(args, in: view, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func noWindow() -> FlutterError {
    FlutterError(code: "no_window", message: "The Flutter view is not in a window yet.", details: nil)
  }
}
