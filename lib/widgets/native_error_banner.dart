import 'package:flutter/material.dart';

import '../core/native_bridge.dart';
import '../core/theme.dart';

/// Bandeau rouge affiché quand Flutter n'arrive pas à parler au code Android.
/// Invisible quand tout va bien et sur iOS (mode démo).
class NativeErrorBanner extends StatelessWidget {
  const NativeErrorBanner({
    super.key,
    this.onDiagnostic,
    this.margin = const EdgeInsets.fromLTRB(20, 10, 20, 0),
  });

  /// Ouvre l'écran Diagnostic.
  final VoidCallback? onDiagnostic;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    if (!NativeBridge.supported) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: NativeBridge.bridgeError,
      builder: (BuildContext context, String? error, Widget? child) {
        if (error == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: margin,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Neon.fade(Neon.red, 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Neon.fade(Neon.red, 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'LIAISON ANDROID INDISPONIBLE',
                style: displayStyle(size: 12, color: Neon.red, spacing: 2),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(color: Neon.text, fontSize: 12, height: 1.35),
              ),
              if (onDiagnostic != null) ...<Widget>[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onDiagnostic,
                  child: Text(
                    'OUVRIR LE DIAGNOSTIC  ›',
                    style: displayStyle(size: 11, color: Neon.cyan, spacing: 2),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
