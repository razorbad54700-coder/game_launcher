/// 0 -> « 0 min », 45 000 -> « < 1 min », 3 900 000 -> « 1 h 05 ».
String formatDuration(int ms) {
  if (ms <= 0) return '0 min';
  final int totalMin = ms ~/ 60000;
  if (totalMin < 1) return '< 1 min';
  final int h = totalMin ~/ 60;
  final int m = totalMin % 60;
  if (h == 0) return '$m min';
  return '$h h ${m.toString().padLeft(2, '0')}';
}

/// Date relative en français : « il y a 5 min », « hier », « jamais ».
String formatAgo(int epochMs, {int? nowMs}) {
  if (epochMs <= 0) return 'jamais';
  final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final int diff = now - epochMs;
  if (diff < 60000) return "à l'instant";
  final int min = diff ~/ 60000;
  if (min < 60) return 'il y a $min min';
  final int h = min ~/ 60;
  if (h < 24) return 'il y a $h h';
  final int d = h ~/ 24;
  if (d == 1) return 'hier';
  if (d < 30) return 'il y a $d j';
  return 'il y a ${d ~/ 30} mois';
}
