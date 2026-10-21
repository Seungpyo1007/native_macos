<p align="center">
  <img src="https://raw.githubusercontent.com/Seungpyo1007/native_macos/main/assets/native_macos-logo.png" alt="native_macos logo: a Mac window with three title bar dots, a switch that is on, and a capsule button" width="128">
</p>

<h1 align="center">native_macos</h1>

<p align="center">
  <a href="https://pub.dev/packages/native_macos"><img src="https://img.shields.io/pub/v/native_macos" alt="pub version"></a>
  <a href="https://pub.dev/packages/native_macos/score"><img src="https://img.shields.io/pub/points/native_macos" alt="pub points"></a>
  <a href="https://github.com/Seungpyo1007/native_macos/actions/workflows/ci.yml"><img src="https://github.com/Seungpyo1007/native_macos/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Seungpyo1007/native_macos/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

Real AppKit controls and Liquid Glass in Flutter macOS apps. Each widget
embeds a native view with `AppKitView`, so macOS draws it: the glass refracts
your Flutter content, and buttons, switches, and sliders look and behave like
every other Mac app, including after the next macOS update. Nothing here is a
Flutter imitation.

```dart
NativeGlassContainer(
  cornerRadius: 20,
  style: NativeGlassStyle.clear,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        NativeButton(
          label: 'Share',
          symbol: 'square.and.arrow.up',
          style: NativeButtonStyle.glass,
          onPressed: share,
        ),
        NativeSwitch(value: sync, onChanged: (v) => setState(() => sync = v)),
      ],
    ),
  ),
)
```

<p align="center">
  <img src="https://raw.githubusercontent.com/Seungpyo1007/native_macos/main/assets/native_macos-showcase.png" alt="The example app in light and dark mode on macOS 27: native push, primary, glass, and destructive buttons, a switch, a checkbox, a segmented control, a pop-up button, a slider, progress indicators, and a small glass panel" width="720">
</p>

## Platform support

| Platform | Native views | Notes |
| --- | --- | --- |
| macOS 26 and later | Yes | Liquid Glass, glass bezels, tint prominence, border shapes, glass groups that blend, a floating glass sidebar. |
| macOS 12 to 25 | Yes | Same controls without glass. Glass surfaces and glass group items use `NSVisualEffectView` and do not blend; glass buttons use the push bezel; the sidebar uses the sidebar material; a circular icon-only button uses the circular bezel. Color well styles need macOS 13. |
| Other platforms and web | No | Each widget shows a Flutter fallback, or the `fallback` you pass. |

Glass needs Xcode 26 or later at build time. With an older Xcode the package
still builds and uses the pre-26 look. `NativeGlassContainer.interactive`
needs macOS 27 and Xcode 27.

## Features

- `NativeToolbar`: a real `NSToolbar` in the window's title bar, with
  buttons, segments, menus, and a search field declared in Dart.
- `NativeGlassContainer`: an `NSGlassEffectView` sized by its child and
  painted under it.
- `NativeGlassGroup` and `NativeGlassGroupItem`: glass shapes in one
  `NSGlassEffectContainerView`, which blend when close and morph when they
  move.
- `NativeSidebar`: a sidebar on the sidebar material, or a floating glass
  panel on macOS 26, optionally resizable.
- `NativeWindow.configure`: subtitle, full-size content, transparent title
  bar, and title bar separator.
- `NativeButton`: `NSButton` with push, glass, or borderless bezels, tint
  prominence, border shape, control size, SF Symbols, and destructive style.
  Default (Return) and cancel (Escape) buttons, `NativeHelpButton`, and
  `NativeDisclosureButton`.
- `NativeSwitch`, `NativeCheckbox`, `NativeSegmentedControl` (with SF
  Symbols), `NativeSegmentedButtons`, `NativeMultiSegmentedControl`,
  `NativeSlider`, `NativePopUpButton`, `NativeProgressIndicator`,
  `NativeDatePicker`, `NativeStepper`, `NativeColorWell`.
- `showNativeAlert` and `showNativeAlertWithResult`: an `NSAlert` as a sheet
  or a modal window, with an optional suppression checkbox and text field.
- `showNativeMenu`: an `NSMenu` at the pointer, for context menus, with
  submenus, checkmarks, and key equivalents.
- `showNativePopover`: an `NSPopover` with a title, a message, and buttons,
  pointing at any Flutter rect.
- Every control takes a `semanticsLabel` and a `tooltip`, and can opt into
  keyboard focus with `focusable`.
- `NativeInputBlocker`: keeps native views from taking clicks under overlays.
- Native views follow your app's theme brightness and text direction, and
  use the user's accent color unless you pass a tint.

## Installation

```sh
flutter pub add native_macos
```

The package requires Dart 3.13 and Flutter 3.47 or newer. No entitlements
are needed; everything works in the App Sandbox.

## Usage

### Toolbar

Wrap a page in `NativeToolbar` to put a real `NSToolbar` on the window. The
toolbar is window chrome drawn by AppKit, not a widget in your layout, so it
looks and behaves like the toolbar in Finder or Mail.

```dart
NativeToolbar(
  title: 'Inbox',
  items: [
    NativeToolbarSegments(
      id: 'view',
      labels: const ['List', 'Grid'],
      symbols: const ['list.bullet', 'square.grid.2x2'],
      selectedIndex: view,
      onChanged: (i) => setState(() => view = i),
    ),
    const NativeToolbarSpace.flexible(),
    NativeToolbarButton(
      id: 'compose',
      label: 'Compose',
      symbol: 'square.and.pencil',
      badge: const NativeToolbarBadge.count(3),
      onPressed: compose,
    ),
    NativeToolbarSearch(id: 'search', onSubmitted: search),
  ],
  child: page,
)
```

Each item needs an `id` that is unique within the toolbar. A window has one
toolbar, and it follows what is on screen: the newest *visible*
`NativeToolbar` owns it. A toolbar in a hidden `IndexedStack` tab or in a
route covered by an opaque route does not count, so switching tabs or
pushing a page without a toolbar changes or removes the window's toolbar,
and popping brings it back. While a dialog or another route covers the
toolbar's route, or a `NativeInputBlocker` above it blocks input, its items
are disabled. While a toolbar is shown, the window follows your app's theme
brightness, and when the last one goes away the window gets back its own
title, title visibility, and toolbar style. The search field keeps its own
text, also when items before it change, and reports edits through
`onChanged` and `onSubmitted`.

### Glass groups

Glass shapes only blend and morph inside one `NSGlassEffectContainerView`.
`NativeGlassGroup` is that container: put `NativeGlassGroupItem`s anywhere
below it, and the group draws their glass together.

```dart
NativeGlassGroup(
  spacing: 16,
  child: Row(
    children: [
      NativeGlassGroupItem(cornerRadius: 22, child: playButton),
      AnimatedContainer(duration: duration, width: apart ? 48 : 4),
      NativeGlassGroupItem(cornerRadius: 22, child: nextButton),
    ],
  ),
)
```

Items closer than `spacing` blend into one shape, and an item that moves
morphs instead of jumping. The group measures its items after each layout
and paint, so animate them with layout or painting widgets
(`AnimatedContainer`, `AnimatedAlign`); an item moved only by a compositing
transform keeps its old glass until it paints again. Before macOS 26 each
item is a separate `NSVisualEffectView`.

### Sidebar and window

```dart
NativeSidebar(
  resizable: true,
  sidebar: sourceList,
  child: content,
)

await NativeWindow.configure(
  subtitle: '3 items',
  fullSizeContent: true,
  transparentTitlebar: true,
);
final metrics = await NativeWindow.metrics();
```

With the automatic style, the sidebar is a floating glass panel inset by
`glassInset` on macOS 26 and the sidebar material before it; `sidebar` is
padded to match. Give the sidebar content no background of its own, or it
covers the native one. With `fullSizeContent`, Flutter draws under the title
bar; pad content that must stay visible by `metrics.titlebarHeight`.

### Glass styles

`NativeGlassStyle.regular`, the default as in AppKit, is frosted: it keeps
text legible, and on a large panel it looks much like a blur.
`NativeGlassStyle.clear` is more transparent and visibly bends the content
behind its edges, which is the lens look most people know as Liquid Glass.
Use `clear` over colorful content, and `regular` where the panel holds a lot
of text.

### Controls

Controls are driven by your state, like Flutter's own. A null callback
disables the control.

```dart
NativeSegmentedControl(
  labels: const ['Icons', 'List', 'Columns'],
  selectedIndex: view,
  onChanged: (i) => setState(() => view = i),
)

NativeSlider(
  value: volume,
  onChanged: (v) => setState(() => volume = v),
  onChangeEnd: save,
)

NativePopUpButton<Sort>(
  value: sort,
  onChanged: (v) => setState(() => sort = v),
  items: const [
    NativeMenuItem(title: 'Name', value: Sort.name),
    NativeMenuItem(title: 'Date Modified', value: Sort.date),
    NativeMenuDivider(),
    NativeMenuItem(title: 'Size', value: Sort.size),
  ],
)
```

More controls follow the same pattern:

```dart
NativeDatePicker(value: date, onChanged: (v) => setState(() => date = v))
NativeStepper(value: copies, min: 1, max: 99, onChanged: setCopies)
NativeColorWell(value: color, onChanged: (v) => setState(() => color = v))
NativeMultiSegmentedControl(
  labels: const ['Bold', 'Italic', 'Underline'],
  symbols: const ['bold', 'italic', 'underline'],
  selected: styles,
  onChanged: (v) => setState(() => styles = v),
)
NativeSegmentedButtons(
  labels: const ['Back', 'Forward'],
  symbols: const ['chevron.left', 'chevron.right'],
  onPressed: (i) => i == 0 ? back() : forward(),
)
NativeDisclosureButton(expanded: open, onChanged: (v) => setState(() => open = v))
NativeHelpButton(onPressed: showHelp)
```

If the parent does not rebuild with the new value by the next frame, the
native control goes back to the old one. Call `setState` before any `await`
in the callback, or the control flickers back and forth.

### Alerts and menus

```dart
final index = await showNativeAlert(
  context: context,
  title: 'Delete this item?',
  message: 'You cannot undo this action.',
  buttons: const [
    NativeAlertButton('Delete', destructive: true),
    NativeAlertButton('Cancel', isCancel: true),
  ],
);

GestureDetector(
  onSecondaryTapUp: (details) async {
    final action = await showNativeMenu<String>(
      context: context,
      globalPosition: details.globalPosition,
      items: const [
        NativeMenuItem(title: 'Copy', value: 'copy', symbol: 'doc.on.doc'),
        NativeMenuItem(title: 'Rename', value: 'rename'),
      ],
    );
  },
  child: row,
)
```

Menu items can show a checkmark and a key equivalent, and a
`NativeSubmenu` nests items:

```dart
const NativeMenuItem(
  title: 'Copy',
  value: 'copy',
  shortcut: NativeMenuShortcut('c'),
),
NativeSubmenu(
  title: 'Sort By',
  items: [
    NativeMenuItem(title: 'Name', value: 'name', checked: sort == 'name'),
    NativeMenuItem(title: 'Size', value: 'size', checked: sort == 'size'),
  ],
),
```

Key equivalents choose an item while its menu is open; they do not register
app-wide shortcuts. `NativePopUpButton` does not take submenus.

```dart
final result = await showNativeAlertWithResult(
  context: context,
  title: 'Rename item',
  textField: const NativeAlertTextField(text: 'Untitled'),
  suppressionLabel: 'Do not ask again',
  buttons: const [
    NativeAlertButton('Rename', isDefault: true),
    NativeAlertButton('Cancel', isCancel: true),
  ],
);
if (result.index == 0) rename(result.text!);

final box = context.findRenderObject()! as RenderBox;
final choice = await showNativePopover<String>(
  context: context,
  anchor: box.localToGlobal(Offset.zero) & box.size,
  title: 'Share this page?',
  actions: const [
    NativePopoverAction('Cancel', value: 'cancel'),
    NativePopoverAction('Copy Link', value: 'copy', isDefault: true),
  ],
);
```

`showNativeAlert` returns the index of the pressed button, or -1 if the
alert closed without one. A popover returns the chosen action's value, or
null when it closes another way. Both throw `UnsupportedError` off macOS, and `NativeMacosException` with code
`no_window` when the Flutter view is not in a window yet.

### Overlays

AppKit views take clicks anywhere Flutter has not painted, even under the
transparent barrier of a Flutter dialog. Block them while an overlay is open:

```dart
NativeInputBlocker(
  blocked: dialogOpen,
  child: page,
)
```

### Fallbacks and checks

```dart
NativeSwitch(
  value: on,
  onChanged: toggle,
  fallback: Switch(value: on, onChanged: toggle),
)

await NativeMacos.loadCapabilities(); // optional, see below
if (NativeMacos.hasLiquidGlass) { /* glass is drawn */ }
```

### Accessibility and keyboard

Every control takes `semanticsLabel`, the AppKit accessibility label (give
one to icon-only buttons), and `tooltip`, its help tag. Controls refuse
keyboard focus by default, so key presses stay with Flutter and your
shortcuts keep working. Pass `focusable: true` to let a click or Full
Keyboard Access focus the control; while it has focus, keys go to AppKit
until the user clicks Flutter content again. `NativeDatePicker` is focusable
by default, because its text fields need the keyboard. `NativeButton`'s
`isDefault` and `isCancel` give it Return and Escape when Flutter does not
handle those keys.

`NativeToolbar` takes a `displayMode` for icons and labels (labels show with
`NativeToolbarStyle.expanded`; the unified styles keep icons only), segment
`tooltips`, and a `NativeToolbarSearchController` that reads and sets the
search field's text.

`hasLiquidGlass` is true when native views actually draw Liquid Glass, which
needs macOS 26 and an app built with Xcode 26 or later. The first native
widget asks the native side, which knows both; until that answer arrives
only the macOS version is checked. Await `NativeMacos.loadCapabilities()`
before the first frame if you branch on it there.

## Example

```sh
cd example
flutter run -d macos
```

## Limitations

These come from how Flutter embeds AppKit views today.

- `gestureRecognizers` do nothing on macOS. Native controls handle the mouse
  themselves, so a Flutter `GestureDetector` around one does not see its
  clicks.
- Flutter's Tab traversal does not move into native views. A `focusable`
  control takes focus from a click or Full Keyboard Access, and gives it back
  when the user clicks Flutter content.
- Flutter's semantics tree does not include native views, so VoiceOver may
  not reach them while Flutter semantics are on. `semanticsLabel` is the
  label AppKit reports when it does, such as for a focused control.
- Flutter blocks native input by the bounding box of what it paints, so a
  border or shadow over a native view can block the whole area.
- Clips other than rectangles, rounded rectangles, and ovals are ignored, and
  perspective transforms render wrongly.
- `BackdropFilter`, `ColorFiltered`, `ShaderMask`, and route transitions with
  image filters do not apply to native views. Native glass can sample Flutter
  pixels, but Flutter cannot sample native pixels.
- Each native view is created asynchronously and is blank for its first
  frame. Sizes start from an estimate and settle once AppKit reports the
  fitting size.
- Each native view with Flutter content above it costs one extra
  window-sized surface. Use native views for controls and navigation, not for
  long lists.
- Only the main Flutter view is supported; multi-window is still
  experimental in Flutter. `NativeToolbar` replaces any toolbar you set on
  that window yourself. `NativeToolbar` item order follows the app's
  language as in every AppKit toolbar; a right-to-left `Directionality`
  changes its menus and search field only.

## Related packages

- [native_trend](https://pub.dev/packages/native_trend) picks pub.dev
  packages that render the latest platform design with native views, and
  writes the result for your AI coding assistant.
