import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_styles.dart';

// Layar modul cukup mengimpor file ini: gaya dan komponen keadaan ikut diekspor.
export 'package:pilihyuk_mobile/screens/data_correction/correction_styles.dart';
export 'package:pilihyuk_mobile/screens/data_correction/state_views.dart';

/// Pesan untuk 403 authentication_required (sesi habis).
const sessionEndedMessage = 'Sesi berakhir. Masuk lagi untuk melanjutkan.';
const withdrawnMessage = 'Pengajuan berhasil ditarik.';

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

/// Chip pilihan filter seperti .chip di web: terpilih hijau muda bergaris hijau, lainnya putih bergaris abu.
class FilterChoice extends StatelessWidget {
  const FilterChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CorrectionColors.primary : CorrectionColors.ink;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: CorrectionColors.surface,
      selectedColor: CorrectionColors.soft,
      side: BorderSide(
        color: selected ? CorrectionColors.primary : CorrectionColors.tertiary,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// "Halaman x dari y" dengan Sebelumnya dan Berikutnya (null = nonaktif). Tiap tombol mendapat separuh
/// lebar, jadi di layar sempit atau huruf besar teksnya turun baris, tidak meluap.
class PageNav extends StatelessWidget {
  const PageNav({
    super.key,
    required this.page,
    required this.numPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int numPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: CorrectionColors.primary,
      minimumSize: const Size(0, CorrectionSizes.touchTarget),
    );
    return Column(
      children: [
        Text(
          'Halaman $page dari $numPages',
          textAlign: TextAlign.center,
          style: CorrectionText.meta,
        ),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onPrevious,
                  style: style,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left),
                      Flexible(child: Text('Sebelumnya')),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onNext,
                  style: style,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Berikutnya')),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
      decoration: const BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: CorrectionSizes.controlRadius,
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
            const SizedBox(height: CorrectionSizes.gapMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CorrectionText.sectionTitle,
            ),
            const SizedBox(height: CorrectionSizes.gapXs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CorrectionText.bodyMuted,
            ),
            const SizedBox(height: CorrectionSizes.gapLg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: CorrectionButtons.primary(
                      background: CorrectionColors.tertiary,
                      foreground: CorrectionColors.ink,
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: CorrectionSizes.gapSm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: CorrectionButtons.primary(
                      background: CorrectionColors.error,
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
      style: CorrectionButtons.outlined(
        foreground: CorrectionColors.error,
        border: CorrectionColors.error.withValues(alpha: 0.4),
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

/// Hasil DELETE mine/{id}/. success: 204. gone: pengajuan sudah tidak ada (204 atau 404). reload: data di layar
/// perlu dimuat ulang (gone, atau 409 karena kurator baru saja meninjau). message: teks untuk toast.
typedef WithdrawOutcome = ({
  bool success,
  bool gone,
  bool reload,
  String message,
});

Future<WithdrawOutcome> withdrawCorrection(CorrectionApi api, int id) async {
  try {
    await api.withdraw(id);
    return (success: true, gone: true, reload: true, message: withdrawnMessage);
  } on ApiError catch (error) {
    final gone = error.status == 404;
    return (
      success: false,
      gone: gone,
      reload: gone || error.status == 409,
      message: error.needsLogin ? sessionEndedMessage : error.message,
    );
  }
}
