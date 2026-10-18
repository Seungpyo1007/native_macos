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

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
