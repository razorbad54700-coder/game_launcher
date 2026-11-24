import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_launcher/core/achievements.dart';
import 'package:game_launcher/core/app_state.dart';
import 'package:game_launcher/core/formatters.dart';
import 'package:game_launcher/core/library_store.dart';
import 'package:game_launcher/core/settings.dart';
import 'package:game_launcher/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(0), '0 min');
    expect(formatDuration(45000), '< 1 min');
    expect(formatDuration(5 * 60000), '5 min');
    expect(formatDuration(65 * 60000), '1 h 05');
  });

  test('formatAgo', () {
    expect(formatAgo(0), 'jamais');
    expect(formatAgo(1000000, nowMs: 1030000), "à l'instant");
    expect(formatAgo(1000000, nowMs: 1000000 + 5 * 60000), 'il y a 5 min');
  });

  test('les réglages sont bornés et sauvegardés', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      's_volume': 7.5,
      's_temp_warn': 99,
      's_sort': 42,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SettingsController s = SettingsController(prefs);
    expect(s.musicVolume, 1.0);
    expect(s.tempWarn, 55);
    expect(s.sortMode, SortMode.favoritesFirst);
    await s.setMuted(true);
    expect(prefs.getBool('s_muted'), true);
  });

  test('bibliothèque : favoris et statistiques', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final LibraryStore lib = LibraryStore(prefs);
    await lib.toggleFavorite('a.b.c');
    expect(lib.isFavorite('a.b.c'), true);
    await lib.recordLaunch('a.b.c');
    await lib.recordLaunch('a.b.c');
    expect(lib.statsFor('a.b.c').launches, 2);
    expect(lib.totalLaunches, 2);
    expect(lib.distinctGamesLaunched, 1);
  });

  test('succès', () {
    const AchievementInput zero = AchievementInput(
      launches: 0,
      distinctGames: 0,
      playMs: 0,
      boosts: 0,
      freedMb: 0,
      favorites: 0,
      dndCount: 0,
      gamesCount: 0,
    );
    expect(allAchievements.where((Achievement a) => a.isUnlocked(zero)), isEmpty);
    const AchievementInput one = AchievementInput(
      launches: 1,
      distinctGames: 1,
      playMs: 0,
      boosts: 0,
      freedMb: 0,
      favorites: 0,
      dndCount: 0,
      gamesCount: 1,
    );
    expect(allAchievements.first.isUnlocked(one), true);
  });

  testWidgets('l\'appli démarre et la navigation fonctionne', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      's_boot_intro': false,
      's_muted': true,
      's_haptics': false,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppState app = AppState.create(prefs);

    await tester.pumpWidget(GameLauncherApp(app: app));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('MON GARAGE'), findsOneWidget);

    expect(find.text('GAMING'), findsOneWidget);
    expect(find.text('STATS'), findsOneWidget);

    await tester.tap(find.text('GAMING'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MODE GAMING'), findsOneWidget);
  });
}
