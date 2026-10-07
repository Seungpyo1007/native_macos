import 'package:flutter/material.dart';
import 'package:native_macos/native_macos.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'native_macos',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const ControlsPage(),
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
    final glass = NativeMacos.hasLiquidGlass
        ? 'Liquid Glass (macOS ${NativeMacos.macOSVersion})'
        : 'macOS ${NativeMacos.macOSVersion ?? '?'}: no Liquid Glass';
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(glass, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              _Section(
                title: 'Buttons',
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      NativeButton(
                        label: 'Push',
                        onPressed: () => setState(() => _presses++),
                      ),
                      NativeButton(
                        label: 'Glass',
                        style: NativeButtonStyle.glass,
                        onPressed: () => setState(() => _presses++),
                      ),
                      NativeButton(
                        label: 'Primary',
                        style: NativeButtonStyle.glass,
                        prominence: NativeTintProminence.primary,
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
                  Text('Pressed $_presses times. Last alert: $_last'),
                ],
              ),
              _Section(
                title: 'Toggles',
                children: [
                  Row(
                    children: [
                      const Text('Wi-Fi'),
                      const SizedBox(width: 12),
                      NativeSwitch(
                        value: _wifi,
                        onChanged: (v) => setState(() => _wifi = v),
                      ),
                    ],
                  ),
                  NativeCheckbox(
                    value: _sync,
                    label: 'Sync with iCloud',
                    onChanged: (v) => setState(() => _sync = v),
                  ),
                ],
              ),
              _Section(
                title: 'Selection',
                children: [
                  NativeSegmentedControl(
                    labels: const ['Icons', 'List', 'Columns'],
                    selectedIndex: _view,
                    onChanged: (i) => setState(() => _view = i),
                  ),
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
                  GestureDetector(
                    onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
                    child: const Text('Right-click here for a native menu'),
                  ),
                ],
              ),
              _Section(
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
                      SizedBox(width: 12),
                      Text('Indeterminate'),
                    ],
                  ),
                ],
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
        NativeAlertButton('Cancel', isDefault: true),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NativeGlassContainer(
        cornerRadius: 20,
        style: NativeGlassStyle.clear,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Colorful shapes so the glass has something to refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final (i, color) in [
          Colors.orange,
          Colors.pink,
          Colors.teal,
          Colors.indigo,
        ].indexed)
          Positioned(
            left: 40.0 + i * 140,
            top: 60.0 + (i.isEven ? 0 : 220),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
