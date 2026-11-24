import 'package:flutter/material.dart';

/// Warna bersama halaman Antrean Data: token Figma (285:5593) dan warna khusus web.
abstract final class CorrectionColors {
  static const canvas = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF1EEE7);
  static const tertiary = Color(0xFFE9E5DB);
  static const border = Color(0xFFE4E0D6);
  static const strong = Color(0xFFCFC9BB);
  static const ink = Color(0xFF16201A);
  static const ink2 = Color(0xFF3C443E);
  static const muted = Color(0xFF6E756E);
  static const muted2 = Color(0xFF969C95);
  static const primary = Color(0xFF1E6F4C);
  static const hover = Color(0xFF16583C);
  static const soft = Color(0xFFE1EFE6);
  static const accent = Color(0xFFDE7A33);
  static const accentSoft = Color(0xFFFBEBDD);
  static const warning = Color(0xFFB47800);
  static const warningSoft = Color(0xFFFBF0D6);
  static const error = Color(0xFFC0341F);
  static const errorSoft = Color(0xFFFAE3DF);

  // Khusus situs web (templates/components/tailwind.html dan _status_chip.html).
  static const accentText = Color(0xFFA33D00);
  static const leaf = Color(0xFFE4EFE0);
  static const missing = Color(0xFFFDF0C4);
  static const missingText = Color(0xFF6B4D00);
}

/// Pesan galat dengan tombol "Coba lagi". Berupa ListView, jadi tetap bisa ditarik untuk memuat ulang.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(
          Icons.error_outline,
          size: 40,
          color: CorrectionColors.error,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ),
      ],
    );
  }
}
