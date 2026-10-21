import Cocoa
import FlutterMacOS

/// Builds the window's `NSToolbar` from Dart's item list and reports item
/// events back to Dart.
final class ToolbarController: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
  /// A new identifier for each toolbar. AppKit keeps toolbars that share an
  /// identifier in sync, so a fixed one would mirror item changes into other
  /// windows' toolbars, and out of range when they have fewer items.
  static func makeToolbarIdentifier() -> NSToolbar.Identifier {
    NSToolbar.Identifier("native_macos.toolbar.\(UUID().uuidString)")
  }

  /// Sends `event` calls to Dart. Replaced in tests.
  var emit: (String, String, Any?) -> Void

  private(set) var toolbar: NSToolbar?
  private weak var window: NSWindow?
  private var specs: [[String: Any]] = []
  /// Each item's kind and structure; a change here rebuilds the toolbar
  /// instead of updating items in place.
  private var shape: [String] = []
  private var searchIds: [ObjectIdentifier: String] = [:]
  /// Search items by Dart id, reused when the toolbar is rebuilt so the
  /// field keeps its text.
  private var searchItems: [String: NSSearchToolbarItem] = [:]
  /// The Dart session that set the toolbar.
  private(set) var session: String?
  /// The window's own settings from before the toolbar, put back by clear.
  private var saved: SavedWindow?

  private struct SavedWindow {
    let toolbar: NSToolbar?
    let appearance: NSAppearance?
    let title: String
    let titleVisibility: NSWindow.TitleVisibility
    let toolbarStyle: NSWindow.ToolbarStyle
  }

  init(emit: @escaping (String, String, Any?) -> Void) {
    self.emit = emit
  }

  convenience init(channel: FlutterMethodChannel) {
    self.init { id, type, value in
      channel.invokeMethod("event", arguments: ["id": id, "type": type, "value": value as Any])
    }
  }

  /// Whether the toolbar was set by a Dart session other than [session].
  func isStale(for session: String) -> Bool {
    toolbar != nil && self.session != nil && self.session != session
  }

  func set(_ p: [String: Any], window: NSWindow) {
    let next = p["items"] as? [[String: Any]] ?? []
    let nextShape = next.map(Self.shape(of:))
    session = p["session"] as? String

    if let toolbar, self.window === window, window.toolbar === toolbar {
      specs = next
      if nextShape != shape {
        // Keep the items before the first difference, so a search field
        // there keeps its text and focus, and rebuild the rest.
        let kept = zip(shape, nextShape).prefix { $0 == $1 }.count
        shape = nextShape
        while toolbar.items.count > kept { toolbar.removeItem(at: toolbar.items.count - 1) }
        let liveIds = Set(next.compactMap { $0["kind"] as? String == "search" ? $0["id"] as? String : nil })
        searchItems = searchItems.filter { liveIds.contains($0.key) }
        searchIds = Dictionary(uniqueKeysWithValues: searchItems.map { (ObjectIdentifier($1.searchField), $0) })
        for (item, spec) in zip(toolbar.items, next) { configure(item, with: spec) }
        for index in kept..<next.count {
          toolbar.insertItem(withItemIdentifier: identifier(for: next[index], at: index), at: index)
        }
      } else {
        for (item, spec) in zip(toolbar.items, next) { configure(item, with: spec) }
      }
    } else {
      if self.window !== window || saved == nil {
        saved = SavedWindow(
          toolbar: window.toolbar, appearance: window.appearance, title: window.title,
          titleVisibility: window.titleVisibility, toolbarStyle: window.toolbarStyle)
      }
      // A new toolbar fills itself from toolbarDefaultItemIdentifiers, so
      // the specs must be in place before it is attached.
      specs = next
      shape = nextShape
      searchIds = [:]
      searchItems = [:]
      let toolbar = NSToolbar(identifier: Self.makeToolbarIdentifier())
      toolbar.delegate = self
      toolbar.displayMode = .iconOnly
      toolbar.allowsUserCustomization = false
      self.toolbar = toolbar
      self.window = window
      window.toolbar = toolbar
    }

    window.appearance = NSAppearance(named: p["brightness"] as? String == "dark" ? .darkAqua : .aqua)
    if let title = p["title"] as? String { window.title = title }
    window.titleVisibility = p["showsTitle"] as? Bool ?? true ? .visible : .hidden
    switch p["style"] as? String {
    case "expanded": window.toolbarStyle = .expanded
    case "unifiedCompact": window.toolbarStyle = .unifiedCompact
    case "automatic": window.toolbarStyle = .automatic
    default: window.toolbarStyle = .unified
    }
  }

  /// Removes the toolbar and puts back the window's own settings.
  func clear(window: NSWindow?) {
    if let window, window.toolbar === toolbar {
      if let saved, self.window === window {
        window.toolbar = saved.toolbar
        window.appearance = saved.appearance
        window.title = saved.title
        window.titleVisibility = saved.titleVisibility
        window.toolbarStyle = saved.toolbarStyle
      } else {
        window.toolbar = nil
        window.appearance = nil
      }
    }
    toolbar = nil
    saved = nil
    session = nil
    specs = []
    shape = []
    searchIds = [:]
    searchItems = [:]
  }

  private static func shape(of spec: [String: Any]) -> String {
    let kind = spec["kind"] as? String ?? ""
    let id = spec["id"] as? String ?? ""
    switch kind {
    case "segments":
      let labels = (spec["labels"] as? [String] ?? []).joined(separator: "\u{1f}")
      let symbols = (spec["symbols"] as? [String] ?? []).joined(separator: "\u{1f}")
      return "\(kind)|\(id)|\(labels)|\(symbols)"
    default:
      return "\(kind)|\(id)"
    }
  }

  private func identifier(for spec: [String: Any], at index: Int) -> NSToolbarItem.Identifier {
    switch spec["kind"] as? String {
    case "flexibleSpace": return .flexibleSpace
    case "space": return .space
    default: return NSToolbarItem.Identifier("native_macos.item.\(spec["id"] as? String ?? "\(index)")")
    }
  }

  private func spec(for identifier: NSToolbarItem.Identifier) -> [String: Any]? {
    specs.enumerated().first { self.identifier(for: $1, at: $0) == identifier }?.element
  }

  // MARK: NSToolbarDelegate

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    specs.enumerated().map { identifier(for: $1, at: $0) }
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard let spec = spec(for: itemIdentifier) else { return nil }
    let item: NSToolbarItem
    switch spec["kind"] as? String {
    case "segments":
      let labels = spec["labels"] as? [String] ?? []
      let images = (spec["symbols"] as? [String])?.enumerated().map { i, name in
        NSImage(systemSymbolName: name, accessibilityDescription: labels[safe: i]) ?? NSImage()
      }
      let group =
        images.map {
          NSToolbarItemGroup(
            itemIdentifier: itemIdentifier, images: $0, selectionMode: .selectOne, labels: labels,
            target: self, action: #selector(segmentChanged(_:)))
        }
        ?? NSToolbarItemGroup(
          itemIdentifier: itemIdentifier, titles: labels, selectionMode: .selectOne, labels: labels,
          target: self, action: #selector(segmentChanged(_:)))
      item = group
    case "menu":
      item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
    case "search":
      let id = spec["id"] as? String ?? ""
      if let existing = searchItems[id], existing.itemIdentifier == itemIdentifier {
        item = existing
      } else {
        let search = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        search.searchField.delegate = self
        search.searchField.sendsWholeSearchString = true
        search.searchField.target = self
        search.searchField.action = #selector(searchSubmitted(_:))
        searchIds[ObjectIdentifier(search.searchField)] = id
        searchItems[id] = search
        item = search
      }
    default:
      item = NSToolbarItem(itemIdentifier: itemIdentifier)
      item.target = self
      item.action = #selector(buttonPressed(_:))
      item.isBordered = true
    }
    configure(item, with: spec)
    return item
  }

  /// Applies the parts of [spec] that can change without rebuilding.
  private func configure(_ item: NSToolbarItem, with spec: [String: Any]) {
    let label = spec["label"] as? String ?? ""
    let enabled = spec["enabled"] as? Bool ?? true
    switch spec["kind"] as? String {
    case "button":
      item.label = label
      item.toolTip = spec["tooltip"] as? String ?? label
      item.image = decodeImage(spec["symbol"], label: label)
      item.title = item.image == nil ? label : ""
      item.isEnabled = enabled
      #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
          item.style = spec["prominent"] as? Bool == true ? .prominent : .plain
          item.backgroundTintColor = decodeColor(spec["tint"])
          item.badge = decodeBadge(spec["badge"])
        }
      #endif
    case "segments":
      guard let group = item as? NSToolbarItemGroup else { return }
      let index = spec["selectedIndex"] as? Int ?? -1
      group.selectedIndex = (0..<group.subitems.count).contains(index) ? index : -1
      group.isEnabled = enabled
      group.subitems.forEach { $0.isEnabled = enabled }
    case "menu":
      guard let menuItem = item as? NSMenuToolbarItem else { return }
      menuItem.label = label
      menuItem.toolTip = label
      menuItem.image = decodeImage(spec["symbol"], label: label)
      menuItem.title = menuItem.image == nil ? label : ""
      menuItem.isEnabled = enabled
      let menu = NSMenu()
      menu.autoenablesItems = false
      let id = spec["id"] as? String
      for entry in makeMenuItems(spec["items"] as? [[String: Any]] ?? [], target: self, action: #selector(menuSelected(_:))) {
        entry.representedObject = id
        menu.addItem(entry)
      }
      menuItem.menu = menu
    case "search":
      guard let search = item as? NSSearchToolbarItem else { return }
      search.searchField.placeholderString = spec["placeholder"] as? String
    default:
      break
    }
  }

  #if compiler(>=6.2)
    @available(macOS 26.0, *)
    private func decodeBadge(_ v: Any?) -> NSItemBadge? {
      guard let b = v as? [String: Any] else { return nil }
      if let count = b["count"] as? Int { return .count(count) }
      if let text = b["text"] as? String { return .text(text) }
      return b["indicator"] as? Bool == true ? .indicator : nil
    }
  #endif

  // MARK: Events

  private func id(of item: NSToolbarItem) -> String? {
    spec(for: item.itemIdentifier)?["id"] as? String
  }

  @objc func buttonPressed(_ sender: NSToolbarItem) {
    if let id = id(of: sender) { emit(id, "pressed", nil) }
  }

  @objc func segmentChanged(_ sender: NSToolbarItemGroup) {
    if let id = id(of: sender) { emit(id, "changed", sender.selectedIndex) }
  }

  @objc func menuSelected(_ sender: NSMenuItem) {
    if let id = sender.representedObject as? String { emit(id, "selected", sender.tag) }
  }

  @objc func searchSubmitted(_ sender: NSSearchField) {
    if let id = searchIds[ObjectIdentifier(sender)] { emit(id, "submitted", sender.stringValue) }
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSSearchField,
      let id = searchIds[ObjectIdentifier(field)]
    else { return }
    emit(id, "changed", field.stringValue)
  }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
