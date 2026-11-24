/// Petit journal en mémoire des erreurs de l'appli. L'écran « Diagnostic »
/// l'affiche et permet de le copier pour le partager.
class AppLog {
  AppLog._();

  static final List<String> entries = <String>[];

  static void add(String message) {
    final String time = DateTime.now().toIso8601String().substring(11, 19);
    entries.add('$time  $message');
    if (entries.length > 40) entries.removeAt(0);
  }
}
