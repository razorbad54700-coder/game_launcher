/// Plugin Android du Game Launcher.
///
/// Rien à importer ici : le plugin s'enregistre tout seul dans Android et
/// répond sur le canal « gamelauncher/native » (voir lib/core/native_bridge.dart
/// dans l'appli). C'est ce qui évite de modifier MainActivity.kt.
library game_launcher_native;
