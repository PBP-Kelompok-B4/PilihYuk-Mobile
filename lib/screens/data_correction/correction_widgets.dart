import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';

/// Pesan untuk 403 authentication_required (sesi habis).
const sessionEndedMessage = 'Sesi berakhir. Masuk lagi untuk melanjutkan.';
const withdrawnMessage = 'Pengajuan berhasil ditarik.';

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

/// Chip "Tidak diketahui" untuk nilai kosong, warnanya sama dengan web.
class UnknownChip extends StatelessWidget {
  const UnknownChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CorrectionColors.missing,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Tidak diketahui',
        style: TextStyle(
          color: CorrectionColors.missingText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Chip status pengajuan atau item. Warnanya sama dengan _status_chip.html: Menunggu abu, Disetujui hijau,
/// Ditolak merah, Sebagian disetujui hijau muda.
class CorrectionStatusChip extends StatelessWidget {
  const CorrectionStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CorrectionStatus.approved => (
        CorrectionColors.soft,
        CorrectionColors.primary,
      ),
      CorrectionStatus.rejected => (
        CorrectionColors.rejectedSoft,
        CorrectionColors.rejectedText,
      ),
      CorrectionStatus.partial => (CorrectionColors.leaf, CorrectionColors.ink),
      _ => (CorrectionColors.secondary, CorrectionColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Catatan "Usulan belum disetujui" di form dan di detail pengajuan yang masih menunggu.
class PendingNotice extends StatelessWidget {
  const PendingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: CorrectionColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: CorrectionColors.warning, fontSize: 13),
                children: [
                  TextSpan(
                    text: 'Usulan belum disetujui. ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: 'Data produk tetap seperti sekarang sampai pengajuan ditinjau kurator.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keadaan kosong: ikon, judul, teks singkat, dan tombol opsional (seperti _empty_state.html di web).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.text = '',
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      decoration: BoxDecoration(
        color: CorrectionColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CorrectionColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CorrectionColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CorrectionColors.muted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CorrectionColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CorrectionColors.muted,
                fontSize: 13,
              ),
            ),
          ],
          if (label != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: CorrectionColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet konfirmasi (Figma 285:8350): ikon merah, judul, teks, tombol "Batal" abu dan tombol merah berikon.
/// true hanya bila tombol konfirmasi ditekan; Batal, X, atau menutup sheet -> false.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.delete_outline,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: CorrectionColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
    ),
  );
  return confirmed == true;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CorrectionColors.errorSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: CorrectionColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CorrectionColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CorrectionColors.muted,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: CorrectionColors.tertiary,
                      foregroundColor: CorrectionColors.ink,
                      shape: shape,
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: CorrectionColors.error,
                      foregroundColor: Colors.white,
                      shape: shape,
                    ),
                    icon: Icon(icon),
                    label: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol "Tarik pengajuan" bergaris merah. busy menampilkan indikator dan menonaktifkan tombol.
class WithdrawButton extends StatelessWidget {
  const WithdrawButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: CorrectionColors.error,
        side: BorderSide(color: CorrectionColors.error.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: busy
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Menarik…'),
              ],
            )
          : const Text('Tarik pengajuan'),
    );
  }
}

/// Konfirmasi tarik dengan teks yang sama dengan _withdraw_dialog.html.
Future<bool> confirmWithdraw(BuildContext context, Correction correction) {
  final name = correction.product.productName.trim();
  return showConfirmSheet(
    context,
    title: 'Tarik pengajuan ini?',
    message:
        'Pengajuan untuk ${name.isEmpty ? 'produk ini' : name} akan dihapus beserta semua usulannya '
        'dan tidak bisa dikembalikan.',
    confirmLabel: 'Tarik Pengajuan',
  );
}

/// Hasil DELETE mine/{id}/. gone: pengajuan sudah tidak ada (204 atau 404). reload: data di layar perlu dimuat
/// ulang (gone, atau 409 karena kurator baru saja meninjau). message: teks untuk SnackBar.
typedef WithdrawOutcome = ({bool gone, bool reload, String message});

Future<WithdrawOutcome> withdrawCorrection(CorrectionApi api, int id) async {
  try {
    await api.withdraw(id);
    return (gone: true, reload: true, message: withdrawnMessage);
  } on ApiError catch (error) {
    final gone = error.status == 404;
    return (
      gone: gone,
      reload: gone || error.status == 409,
      message: error.needsLogin ? sessionEndedMessage : error.message,
    );
  }
}
