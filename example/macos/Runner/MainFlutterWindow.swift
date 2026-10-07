import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 640, height: 770)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Always open at this size instead of the last one.
    self.isRestorable = false
    // Let the app's background run under the title bar.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
