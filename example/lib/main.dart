import 'package:flutter/material.dart';
import 'package:native_macos/native_macos.dart';

/// Pass `--dart-define=THEME=light` or `dark` to ignore the system setting.
const _theme = String.fromEnvironment('THEME');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'native_macos',
      debugShowCheckedModeBanner: false,
      themeMode: switch (_theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: _themeData(Brightness.light),
      darkTheme: _themeData(Brightness.dark),
      home: const ControlsPage(),
    );
  }

  ThemeData _themeData(Brightness brightness) {
    final light = brightness == Brightness.light;
    return ThemeData(
      brightness: brightness,
      colorSchemeSeed: Colors.blue,
      // The window and grouped-box colors of macOS System Settings.
      scaffoldBackgroundColor: light
          ? const Color(0xFFECECEC)
          : const Color(0xFF1E1E1E),
      cardColor: light ? Colors.white : const Color(0xFF2B2B2B),
    );
  }
}

enum Sort { name, date, size }

class ControlsPage extends StatefulWidget {
  const ControlsPage({super.key});

  @override
  State<ControlsPage> createState() => _ControlsPageState();
}

class _ControlsPageState extends State<ControlsPage> {
  bool _wifi = true;
  bool _sync = false;
  int _view = 0;
  double _volume = 0.4;
  Sort _sort = Sort.name;
  int _presses = 0;
  String _last = 'Nothing yet';
  DateTime _date = DateTime(2026, 10, 22);
  double _copies = 1;
  Color _color = const Color(0xFF3478F6);
  bool _details = false;
  Set<int> _styles = {0};
  bool _merged = true;
  int _section = 0;
  final _search = NativeToolbarSearchController();
  final _shareKey = GlobalKey();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NativeToolbar(
      title: 'native_macos',
      items: [
        NativeToolbarSegments(
          id: 'view',
          labels: const ['Icons', 'List', 'Columns'],
          symbols: const [
            'square.grid.2x2',
            'list.bullet',
            'rectangle.split.3x1',
          ],
          selectedIndex: _view,
          onChanged: (i) => setState(() => _view = i),
        ),
        const NativeToolbarSpace.flexible(),
        NativeToolbarMenu<Sort>(
          id: 'sort',
          label: 'Sort',
          symbol: 'arrow.up.arrow.down',
          onSelected: (v) => setState(() => _sort = v),
          items: const [
            NativeMenuItem(title: 'Name', value: Sort.name),
            NativeMenuItem(title: 'Date Modified', value: Sort.date),
            NativeMenuItem(title: 'Size', value: Sort.size),
          ],
        ),
        NativeToolbarButton(
          id: 'share',
          label: 'Share',
          symbol: 'square.and.arrow.up',
          onPressed: () => setState(() => _last = 'toolbar: share'),
        ),
        NativeToolbarButton(
          id: 'inbox',
          label: 'Inbox',
          symbol: 'tray',
          badge: _presses > 0 ? NativeToolbarBadge.count(_presses) : null,
          onPressed: () => setState(() => _presses = 0),
        ),
        NativeToolbarSearch(
          id: 'search',
          placeholder: 'Search',
          controller: _search,
          onSubmitted: (text) => setState(() => _last = 'search: $text'),
        ),
      ],
      child: NativeSidebar(
        resizable: true,
        sidebar: _sidebar(context),
        child: _page(context),
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    const sections = [
      ('Controls', Icons.tune),
      ('Glass', Icons.blur_on),
      ('Windows', Icons.web_asset),
    ];
    // The sidebar has no background of its own: the native one shows.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (i, (title, icon)) in sections.indexed)
            ListTile(
              dense: true,
              leading: Icon(icon, size: 18),
              title: Text(title),
              selected: _section == i,
              onTap: () => setState(() => _section = i),
            ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Group(
            title: 'Buttons',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NativeButton(
                    label: 'Push',
                    onPressed: () => setState(() => _presses++),
                  ),
                  NativeButton(
                    label: 'Primary',
                    prominence: NativeTintProminence.primary,
                    onPressed: () => setState(() => _presses++),
                  ),
                  NativeButton(
                    label: 'Glass',
                    style: NativeButtonStyle.glass,
                    onPressed: () => setState(() => _presses++),
                  ),
                  NativeButton(
                    label: 'Share',
                    symbol: 'square.and.arrow.up',
                    onPressed: () => setState(() => _presses++),
                  ),
                  NativeButton(
                    label: 'Delete',
                    destructive: true,
                    onPressed: _confirmDelete,
                  ),
                  const NativeButton(label: 'Disabled', onPressed: null),
                ],
              ),
              _Caption('Pressed $_presses times. Last action: $_last'),
            ],
          ),
          _Group(
            title: 'Toggles',
            children: [
              _Row(
                'Wi-Fi',
                NativeSwitch(
                  value: _wifi,
                  onChanged: (v) => setState(() => _wifi = v),
                ),
              ),
              NativeCheckbox(
                value: _sync,
                label: 'Sync with iCloud',
                onChanged: (v) => setState(() => _sync = v),
              ),
            ],
          ),
          _Group(
            title: 'Selection',
            children: [
              _Row(
                'View',
                NativeSegmentedControl(
                  labels: const ['Icons', 'List', 'Columns'],
                  selectedIndex: _view,
                  onChanged: (i) => setState(() => _view = i),
                ),
              ),
              _Row(
                'Sort by',
                NativePopUpButton<Sort>(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                  items: const [
                    NativeMenuItem(title: 'Name', value: Sort.name),
                    NativeMenuItem(title: 'Date Modified', value: Sort.date),
                    NativeMenuDivider(),
                    NativeMenuItem(title: 'Size', value: Sort.size),
                  ],
                ),
              ),
              GestureDetector(
                onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
                child: const _Caption('Right-click here for a native menu.'),
              ),
            ],
          ),
          _Group(
            title: 'Values',
            children: [
              NativeSlider(
                value: _volume,
                onChanged: (v) => setState(() => _volume = v),
              ),
              NativeProgressIndicator(value: _volume),
              const Row(
                children: [
                  NativeProgressIndicator(
                    style: NativeProgressStyle.spinning,
                    controlSize: NativeControlSize.small,
                  ),
                  SizedBox(width: 8),
                  _Caption('Indeterminate'),
                ],
              ),
            ],
          ),
          _Group(
            title: 'More controls',
            children: [
              _Row(
                'Date',
                NativeDatePicker(
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                ),
              ),
              _Row(
                'Copies: ${_copies.round()}',
                NativeStepper(
                  value: _copies,
                  min: 1,
                  max: 99,
                  semanticsLabel: 'Copies',
                  onChanged: (v) => setState(() => _copies = v),
                ),
              ),
              _Row(
                'Accent',
                NativeColorWell(
                  value: _color,
                  supportsAlpha: false,
                  onChanged: (v) => setState(() => _color = v),
                ),
              ),
              _Row(
                'Text style',
                NativeMultiSegmentedControl(
                  labels: const ['Bold', 'Italic', 'Underline'],
                  symbols: const ['bold', 'italic', 'underline'],
                  selected: _styles,
                  onChanged: (v) => setState(() => _styles = v),
                ),
              ),
              _Row(
                'History',
                NativeSegmentedButtons(
                  labels: const ['Back', 'Forward'],
                  symbols: const ['chevron.left', 'chevron.right'],
                  segmentTooltips: const ['Go back', 'Go forward'],
                  onPressed: (i) =>
                      setState(() => _last = i == 0 ? 'back' : 'forward'),
                ),
              ),
              Row(
                children: [
                  NativeDisclosureButton(
                    expanded: _details,
                    semanticsLabel: 'Details',
                    onChanged: (v) => setState(() => _details = v),
                  ),
                  const SizedBox(width: 6),
                  const Text('Details'),
                  const Spacer(),
                  NativeHelpButton(
                    tooltip: 'What these controls are',
                    onPressed: () => setState(() => _last = 'help'),
                  ),
                ],
              ),
              if (_details)
                const _Caption(
                  'NSDatePicker, NSStepper, NSColorWell, and NSSegmentedControl '
                  'in momentary and select-any modes.',
                ),
            ],
          ),
          _Group(
            title: 'Popovers, alerts, and the window',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NativeButton(
                    key: _shareKey,
                    label: 'Popover',
                    onPressed: _showPopover,
                  ),
                  NativeButton(label: 'Rename…', onPressed: _rename),
                  NativeButton(
                    label: 'Subtitle',
                    onPressed: () =>
                        NativeWindow.configure(subtitle: '$_presses presses'),
                  ),
                  NativeButton(label: 'Clear search', onPressed: _search.clear),
                ],
              ),
            ],
          ),
          _Group(
            title: 'Glass group',
            children: [
              NativeCheckbox(
                value: _merged,
                label: 'Close together',
                onChanged: (v) => setState(() => _merged = v),
              ),
              SizedBox(
                height: 56,
                child: NativeGlassGroup(
                  spacing: 16,
                  child: Row(
                    children: [
                      const NativeGlassGroupItem(
                        cornerRadius: 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.play_arrow),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: _merged ? 4 : 48,
                      ),
                      const NativeGlassGroupItem(
                        cornerRadius: 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.skip_next),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _Group(
            title: 'Glass',
            children: [
              NativeGlassContainer(
                cornerRadius: 14,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _Caption(
                    NativeMacos.hasLiquidGlass
                        ? 'Liquid Glass on macOS ${NativeMacos.macOSVersion}'
                        : 'NSVisualEffectView before macOS 26',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final index = await showNativeAlert(
      context: context,
      title: 'Delete this item?',
      message: 'You cannot undo this action.',
      buttons: const [
        NativeAlertButton('Delete', destructive: true),
        NativeAlertButton('Cancel', isCancel: true),
      ],
    );
    setState(() => _last = index == 0 ? 'Delete' : 'Cancel');
  }

  Future<void> _showPopover() async {
    final box = _shareKey.currentContext!.findRenderObject()! as RenderBox;
    final choice = await showNativePopover<String>(
      context: context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      title: 'Share this page?',
      message: 'Anyone with the link can view it.',
      actions: const [
        NativePopoverAction('Cancel', value: 'cancel'),
        NativePopoverAction('Copy Link', value: 'copy', isDefault: true),
      ],
    );
    setState(() => _last = 'popover: ${choice ?? 'dismissed'}');
  }

  Future<void> _rename() async {
    final result = await showNativeAlertWithResult(
      context: context,
      title: 'Rename item',
      style: NativeAlertStyle.informational,
      textField: const NativeAlertTextField(text: 'Untitled'),
      suppressionLabel: 'Do not ask again',
      buttons: const [
        NativeAlertButton('Rename', isDefault: true),
        NativeAlertButton('Cancel', isCancel: true),
      ],
    );
    if (result.index == 0) setState(() => _last = 'renamed: ${result.text}');
  }

  Future<void> _showMenu(Offset position) async {
    final choice = await showNativeMenu<String>(
      context: context,
      globalPosition: position,
      items: const [
        NativeMenuItem(
          title: 'Copy',
          value: 'copy',
          symbol: 'doc.on.doc',
          shortcut: NativeMenuShortcut('c'),
        ),
        NativeMenuItem(title: 'Paste', value: 'paste', enabled: false),
        NativeMenuDivider(),
        NativeMenuItem(title: 'Rename', value: 'rename'),
        NativeSubmenu(
          title: 'Sort By',
          items: [
            NativeMenuItem(title: 'Name', value: 'name', checked: true),
            NativeMenuItem(title: 'Size', value: 'size'),
          ],
        ),
      ],
    );
    if (choice != null) setState(() => _last = 'menu: $choice');
  }
}

/// A titled box like the groups in macOS System Settings.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.control);

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        control,
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
