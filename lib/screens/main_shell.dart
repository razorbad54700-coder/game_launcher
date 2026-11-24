import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/grid_background.dart';
import 'gaming_mode_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Coquille de l'appli : fond animé commun, quatre onglets et barre du bas.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app == null) {
      final AppState app = AppScope.of(context);
      _app = app;
      app.message.addListener(_onMessage);
      // Un message arrivé pendant l'animation de démarrage est affiché ici.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) _onMessage();
      });
    }
  }

  @override
  void dispose() {
    _app?.message.removeListener(_onMessage);
    super.dispose();
  }

  void _onMessage() {
    final AppState? app = _app;
    if (app == null || !mounted) return;
    final String? text = app.message.value;
    if (text == null) return;
    app.message.value = null;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Neon.fade(Neon.cyan, 0.4)),
        ),
      ),
    );
  }

  void _go(int i) {
    if (i == _index) return;
    final AppState? app = _app;
    app?.haptics.select();
    app?.sound.tick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    final List<Widget> tabs = <Widget>[
      HomeScreen(onOpenGaming: () => _go(1)),
      const GamingModeScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      // Retour Android : depuis un onglet, on revient d'abord à l'accueil.
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: Neon.bg,
        body: ListenableBuilder(
          listenable: app.settings,
          builder: (BuildContext context, Widget? child) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GridBackground(animated: !app.settings.lowFx),
                // Le fond est assombri sur les onglets autres que l'accueil.
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Neon.fade(Neon.bg, _index == 0 ? 0.0 : 0.82),
                  ),
                ),
                IndexedStack(
                  index: _index,
                  children: <Widget>[
                    for (int i = 0; i < tabs.length; i++)
                      // Les onglets cachés ne font tourner aucune animation.
                      TickerMode(enabled: i == _index, child: tabs[i]),
                  ],
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _NavBar(index: _index, onTap: _go),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const List<IconData> _icons = <IconData>[
    Icons.sports_esports_rounded,
    Icons.speed_rounded,
    Icons.bar_chart_rounded,
    Icons.tune_rounded,
  ];
  static const List<String> _labels = <String>['ACCUEIL', 'GAMING', 'STATS', 'RÉGLAGES'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Neon.panel,
        border: Border(top: BorderSide(color: Neon.fade(Neon.cyan, 0.2))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < _icons.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _icons[i],
                    label: _labels[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color c = selected ? Neon.red : Neon.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: selected ? Neon.red : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: selected ? Neon.glow(Neon.red, strength: 0.3) : null,
            ),
          ),
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 9.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
