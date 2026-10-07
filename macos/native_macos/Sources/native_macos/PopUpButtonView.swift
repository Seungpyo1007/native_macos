import Cocoa

/// An `NSPopUpButton`. Item tags are their indices in the Dart entry list.
final class PopUpButtonView: NSView, NativeControl {
  var emit: ((String, Any?) -> Void)?
  private let button = NSPopUpButton(frame: .zero, pullsDown: false)
  private var entries: NSArray = []

  override init(frame: NSRect) {
    super.init(frame: frame)
    button.target = self
    button.action = #selector(changed)
    button.refusesFirstResponder = true
    button.autoenablesItems = false
    fill(with: button)
  }

  required init?(coder: NSCoder) { nil }

  @objc private func changed() {
    guard let item = button.selectedItem else { return }
    emit?("changed", ["value": item.tag])
  }

  func apply(_ p: [String: Any]) {
    let next = p["items"] as? [[String: Any]] ?? []
    if !entries.isEqual(to: next) {
      entries = next as NSArray
      button.menu?.removeAllItems()
      for item in makeMenuItems(next, target: self, action: #selector(changed)) {
        button.menu?.addItem(item)
      }
    }
    let index = p["selectedIndex"] as? Int ?? -1
    if index >= 0, index < button.numberOfItems {
      button.selectItem(at: index)
    } else {
      button.select(nil)
    }
    button.isEnabled = p["enabled"] as? Bool ?? true
    button.controlSize = decodeControlSize(p["controlSize"])
  }

  func fittingSizeForFlutter() -> NSSize { button.fittingSize }
}
