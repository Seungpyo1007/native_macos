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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        // The window has no title bar background, so leave room for its buttons.
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
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

  Future<void> _showMenu(Offset position) async {
    final choice = await showNativeMenu<String>(
      context: context,
      globalPosition: position,
      items: const [
        NativeMenuItem(title: 'Copy', value: 'copy', symbol: 'doc.on.doc'),
        NativeMenuItem(title: 'Paste', value: 'paste', enabled: false),
        NativeMenuDivider(),
        NativeMenuItem(title: 'Rename', value: 'rename'),
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
