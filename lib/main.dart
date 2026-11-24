import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_log.dart';
import 'core/app_scope.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/boot_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Toute erreur est notée dans le journal (écran Diagnostic) au lieu de
  // disparaître silencieusement.
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLog.add('Flutter : ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.add('Erreur : $error');
    return true;
  };

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    systemNavigationBarColor: Neon.bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppState app = AppState.create(prefs);
  runApp(GameLauncherApp(app: app));
  // Les mesures et le scan démarrent après le premier affichage.
  app.start();
}

class GameLauncherApp extends StatelessWidget {
  const GameLauncherApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: app,
      child: MaterialApp(
        title: 'Game Launcher',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: app.settings.bootIntro ? const BootScreen() : const MainShell(),
      ),
    );
  }
}
