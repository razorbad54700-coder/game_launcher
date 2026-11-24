# GAME LAUNCHER v2

Lanceur de jeux futuriste (thème sombre, néon rouge et cyan) pour Android, avec
une version démo pour iPhone. Fait avec Flutter.

## Installation (5 commandes)

> **Important : utilise un NOUVEAU dossier.** Ne copie pas ce projet par-dessus
> l'ancien (v1) : l'ancien `MainActivity.kt` entrerait en conflit avec le nouveau
> code Android. Il n'y a plus AUCUN fichier Android à modifier à la main.

1. Dézippe `game_launcher.zip` dans un dossier neuf.
2. Ouvre un terminal dans ce dossier, puis tape :

```bash
cd game_launcher
flutter create --org com.example --project-name game_launcher --platforms=android,ios .
flutter pub get
flutter run
```

La commande `flutter create .` ajoute les dossiers `android/` et `ios/` sans
toucher à `lib/`, à `pubspec.yaml` ni aux sons. Le premier lancement est long
(Gradle télécharge des fichiers) : c'est normal.

Pour un test sur téléphone : active le « Débogage USB » dans les options
développeur, branche le téléphone, accepte la demande, puis `flutter run`.

## Ce que fait l'appli

**Démarrage** : animation high-tech (anneaux HUD, journal système, barre de
progression, flash, titre) sur une musique d'ambiance douce de 10 s. Un toucher
passe l'animation. Le journal affiche l'état réel de la liaison Android, des
capteurs et de la bibliothèque.

**Accueil** : carrousel 3D ou grille, gros bouton LANCER, recherche, filtres
(Tous / Favoris / Récents), 4 tris, favoris, fiche détaillée de chaque jeu,
bandeau batterie / température / RAM, rescan, écran de lancement animé.

**Mode Gaming** : jauges RAM / batterie / température, bouton BOOST (nettoyage de
la RAM + « Ne pas déranger »), 3 profils de lancement (Éco, Équilibré,
Performance) appliqués automatiquement avant chaque jeu, alerte de surchauffe
(seuil réglable, son + vibration), courbes de tendance, détails de la batterie,
stockage, infos de l'appareil. « Ne pas déranger » est remis comme avant à ton
retour dans le lanceur.

**Stats** : lancements, temps de jeu estimé, classement, 12 succès.

**Réglages** : Mute, volume, sons d'interface, vibrations, animation de
démarrage (activer / revoir), écouter la musique, vue grille, mode immersif, mode
économie, afficher toutes les applis, « Mes jeux » (choisir ce qui apparaît),
réinitialisation.

**Diagnostic** (Réglages › Diagnostic) : teste chaque fonction du code Android,
affiche les erreurs et copie un rapport complet.

## Si quelque chose ne marche pas

| Problème | Solution |
|---|---|
| Bandeau rouge « LIAISON ANDROID INDISPONIBLE » | Arrête complètement l'appli (pas un hot reload) puis relance `flutter run`. Vérifie que tu utilises un dossier neuf. Ouvre Réglages › Diagnostic. |
| « Aucun jeu détecté » | Android ne marque pas toujours les jeux comme des jeux. Réglages › « Afficher toutes les applis », puis Réglages › « Mes jeux » pour choisir les tiens. |
| Pas de musique | Réglages › Mute désactivé ? Volume ? Volume multimédia du téléphone ? Essaie Réglages › « Écouter la musique ». |
| « Ne pas déranger » ne s'active pas | Onglet Gaming › AUTORISER, active Game Launcher dans la liste qui s'ouvre, puis reviens. |
| Erreur de compilation | `flutter clean`, puis `flutter pub get`, puis `flutter run`. Envoie-moi les 30 dernières lignes du terminal. |

## Limites à connaître (honnêtement)

- **iPhone** : iOS interdit de lister ou lancer les autres applis, de lire la
  RAM ou de fermer des applis. L'iPhone affiche donc une démo avec des jeux et
  des mesures simulés (c'est indiqué à l'écran).
- **Nettoyage de la RAM** : Android demande aux applis en arrière-plan de se
  fermer. Il ne ferme ni l'appli au premier plan, ni les applis système, et les
  applis peuvent se relancer toutes seules.
- **Température** : c'est celle de la batterie. Android ne donne pas celle du
  processeur aux applis.
- **Temps de jeu** : estimation (durée entre le lancement et ton retour dans le
  lanceur).
- **Musique** : elle est générée par un programme (nappes, cloches, montée) ;
  elle n'a pas été écoutée sur un vrai haut-parleur avant livraison. Si elle ne
  te plaît pas, remplace `assets/audio/boot_music.wav` par ton propre fichier
  (même nom, format WAV) ou coupe-la dans les réglages.

## Structure

```
lib/core/          logique : réglages, bibliothèque, mesures, sons, Mode Gaming
lib/screens/       écrans : démarrage, accueil, gaming, stats, réglages, diagnostic
lib/widgets/       composants : carrousel 3D, jauges, boutons, courbes
packages/game_launcher_native/   code Android (plugin local, branché tout seul)
assets/audio/      musique de démarrage et sons d'interface
```
