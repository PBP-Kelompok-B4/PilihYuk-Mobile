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
  static const rejectedSoft = Color(0xFFFDE7E4);
  static const rejectedText = Color(0xFFB42318);
}

/// Jarak, radius, dan tinggi dari Figma 285:5593 ("Ritme & kontrol").
abstract final class CorrectionSizes {
  /// Jarak tepi halaman.
  static const inset = 20.0;
  static const gapXs = 8.0;
  static const gapSm = 12.0;
  static const gapMd = 16.0;
  static const gapLg = 24.0;
  static const gapXl = 32.0;
  static const cardRadius = BorderRadius.all(Radius.circular(18));

  /// Radius input, tombol, dan kotak kecil.
  static const controlRadius = BorderRadius.all(Radius.circular(10));

  /// Target sentuh minimal, juga tinggi tombol kecil.
  static const touchTarget = 44.0;
  static const buttonHeight = 48.0;
}

/// Skala teks Figma 285:5593 dengan font bawaan (Inter tidak dipasang).
abstract final class CorrectionText {
  static const pageTitle = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );
  static const cardTitle = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Angka besar di kartu statistik.
  static const stat = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  /// Nama produk atau field di dalam daftar.
  static const itemTitle = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Nilai data, mis. "780" atau "Tidak diketahui".
  static const value = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 15,
    height: 1.5,
  );
  static const bodyMuted = TextStyle(
    color: CorrectionColors.muted,
    fontSize: 15,
    height: 1.5,
  );
  static const label = TextStyle(
    color: CorrectionColors.ink,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static const meta = TextStyle(color: CorrectionColors.muted, fontSize: 13);
  static const caption = TextStyle(color: CorrectionColors.muted, fontSize: 12);
}

abstract final class CorrectionDecorations {
  /// Kartu: putih, garis tipis, radius 18.
  static const card = BoxDecoration(
    color: CorrectionColors.surface,
    borderRadius: CorrectionSizes.cardRadius,
    border: Border.fromBorderSide(BorderSide(color: CorrectionColors.border)),
  );

  /// Kotak nilai yang hanya dibaca.
  static const field = BoxDecoration(
    color: CorrectionColors.secondary,
    borderRadius: CorrectionSizes.controlRadius,
  );
}

/// Gaya tombol: tombol utama setinggi 48, tombol kecil setinggi 44, semuanya radius 10.
abstract final class CorrectionButtons {
  static const _shape = RoundedRectangleBorder(
    borderRadius: CorrectionSizes.controlRadius,
  );

  /// Tombol utama selebar induknya, mis. "Ajukan Koreksi". Warna lain untuk "Batal" (abu) atau "Tolak" (merah).
  static ButtonStyle primary({
    Color background = CorrectionColors.primary,
    Color foreground = Colors.white,
  }) => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(CorrectionSizes.buttonHeight),
    backgroundColor: background,
    foregroundColor: foreground,
    disabledBackgroundColor: background.withValues(alpha: 0.45),
    disabledForegroundColor: foreground,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    shape: _shape,
  );

  /// Tombol hijau muda seperti "Lengkapi Data" dan "Review" di web.
  static final tonal = FilledButton.styleFrom(
    minimumSize: const Size(0, CorrectionSizes.touchTarget),
    backgroundColor: CorrectionColors.soft,
    foregroundColor: CorrectionColors.primary,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    shape: _shape,
  );

  /// Tombol bergaris, mis. "Lihat detail"; garis merah untuk "Tarik pengajuan".
  static ButtonStyle outlined({
    Color foreground = CorrectionColors.ink,
    Color border = CorrectionColors.border,
  }) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, CorrectionSizes.touchTarget),
    foregroundColor: foreground,
    side: BorderSide(color: border),
    shape: _shape,
  );
}

/// Kotak isian seperti Figma: putih, garis abu, hijau saat fokus, merah saat galat.
abstract final class CorrectionInputs {
  static InputDecoration decoration({
    String? hint,
    String? helper,
    String? error,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: CorrectionSizes.controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      errorText: error,
      errorMaxLines: 3,
      isDense: true,
      filled: true,
      fillColor: CorrectionColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border(CorrectionColors.strong),
      disabledBorder: border(CorrectionColors.border),
      focusedBorder: border(CorrectionColors.primary, 1.5),
      errorBorder: border(CorrectionColors.error),
      focusedErrorBorder: border(CorrectionColors.error, 1.5),
    );
  }
}
