import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Rend [AppState] accessible partout dans l'arbre : `AppScope.of(context)`.
/// L'objet ne change jamais ; les écrans écoutent eux-mêmes ce qui les
/// concerne avec un ListenableBuilder.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.state, required super.child});

  final AppState state;

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable : enveloppe ton appli dans AppScope.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}
