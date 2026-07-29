import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/gallery_theme.dart';

class ThemeBuilderScreen extends StatefulWidget {
  const ThemeBuilderScreen({super.key});

  @override
  State<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends State<ThemeBuilderScreen> {
  double _glow = .65;
  double _radius = 24;
  double _border = 2;
  bool _particles = true;
  bool _animatedShine = true;
  String _preset = 'Cyberpunk';

  static const presets = {
    'Cyberpunk': [Color(0xFFB86BFF), Color(0xFF180923), Color(0xFFE8E8F0)],
    'Royal Purple': [Color(0xFF9F5DE2), Color(0xFF230A38), Color(0xFFF1D8FF)],
    'Chrome': [Color(0xFFC7CAD4), Color(0xFF15151A), Color(0xFFFFFFFF)],
    'Gold': [Color(0xFFFFD36A), Color(0xFF281B05), Color(0xFFFFF1C0)],
    'Minimal': [Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFFAAAAAA)],
  };

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_builder_preset', _preset);
    await prefs.setDouble('theme_builder_glow', _glow);
    await prefs.setDouble('theme_builder_radius', _radius);
    await prefs.setDouble('theme_builder_border', _border);
    await prefs.setBool('theme_builder_particles', _particles);
    await prefs.setBool('theme_builder_shine', _animatedShine);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Theme recipe saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = presets[_preset]!;
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 850;
        final preview = _ThemePreview(
            colors: colors,
            glow: _glow,
            radius: _radius,
            border: _border,
            particles: _particles,
            animatedShine: _animatedShine);
        final controls = _controls();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: wide
              ? Row(children: [
                  Expanded(child: preview),
                  const SizedBox(width: 20),
                  SizedBox(width: 360, child: controls)
                ])
              : ListView(children: [
                  SizedBox(height: 480, child: preview),
                  const SizedBox(height: 16),
                  controls
                ]),
        );
      }),
    );
  }

  Widget _controls() => Card(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('THEME BUILDER',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _preset,
              decoration: const InputDecoration(labelText: 'Base recipe'),
              items: presets.keys
                  .map((name) =>
                      DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: (value) => setState(() => _preset = value ?? _preset),
            ),
            const SizedBox(height: 16),
            _slider('Glow intensity', _glow, 0, 1,
                (v) => setState(() => _glow = v)),
            _slider('Corner radius', _radius, 4, 42,
                (v) => setState(() => _radius = v)),
            _slider('Border width', _border, 1, 6,
                (v) => setState(() => _border = v)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Particle field'),
                value: _particles,
                onChanged: (v) => setState(() => _particles = v)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animated shine'),
                value: _animatedShine,
                onChanged: (v) => setState(() => _animatedShine = v)),
            const SizedBox(height: 10),
            FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_as_rounded),
                label: const Text('Save Theme Recipe')),
            const SizedBox(height: 8),
            const Text(
                'Theme recipes are saved locally. Applying custom recipes directly to every card is staged for Beta 1.',
                style: TextStyle(color: GalleryColors.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(1)}'),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview(
      {required this.colors,
      required this.glow,
      required this.radius,
      required this.border,
      required this.particles,
      required this.animatedShine});
  final List<Color> colors;
  final double glow;
  final double radius;
  final double border;
  final bool particles;
  final bool animatedShine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Container(
          width: 330,
          height: 470,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors[0], colors[1], Colors.black]),
            border: Border.all(color: colors[2], width: border),
            boxShadow: [
              BoxShadow(
                  color: colors[0].withValues(alpha: glow),
                  blurRadius: 50 * glow,
                  spreadRadius: 6 * glow)
            ],
          ),
          child: Stack(children: [
            if (particles)
              ...List.generate(
                  18,
                  (i) => Positioned(
                      left: ((i * 47) % 300).toDouble() + 10,
                      top: ((i * 83) % 430).toDouble() + 10,
                      child: Icon(Icons.circle,
                          size: 2 + (i % 4).toDouble(),
                          color: colors[2].withValues(alpha: .4)))),
            if (animatedShine)
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: .22),
                                Colors.transparent,
                                colors[0].withValues(alpha: .12)
                              ])))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THOT GALLERY',
                        style: TextStyle(
                            color: colors[2],
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                    const Spacer(),
                    Text('Creator Edition',
                        style: TextStyle(
                            color: colors[2],
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Your Guilty Pleasure',
                        style:
                            TextStyle(color: colors[2].withValues(alpha: .8))),
                    const SizedBox(height: 18),
                    Row(children: [
                      Icon(Icons.auto_awesome, color: colors[2]),
                      const SizedBox(width: 8),
                      Text('LEGENDARY',
                          style: TextStyle(
                              color: colors[2], fontWeight: FontWeight.bold))
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
