import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_styles.dart';

/// Keadaan memuat: indikator di tengah halaman.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: CorrectionColors.primary,
        semanticsLabel: 'Memuat',
      ),
    );
  }
}

/// Keadaan galat (Figma 285:8423): kartu berikon peringatan, pesan, dan tombol "Coba lagi".
/// Bawaannya ListView supaya halaman tetap bisa ditarik; scrollable false untuk di dalam daftar lain.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.scrollable = true,
  });

  final String message;
  final VoidCallback onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final card = _StateCard(
      icon: Icons.warning_amber_rounded,
      iconBackground: CorrectionColors.errorSoft,
      iconColor: CorrectionColors.error,
      title: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        style: CorrectionButtons.primary(),
        icon: const Icon(Icons.refresh),
        label: const Text('Coba lagi'),
      ),
    );
    if (!scrollable) {
      return card;
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(CorrectionSizes.inset),
      children: [card],
    );
  }
}

/// Keadaan kosong (Figma 285:8517): kartu berikon dengan judul, teks singkat, dan tombol opsional.
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
    return _StateCard(
      icon: icon,
      iconBackground: CorrectionColors.secondary,
      iconColor: CorrectionColors.muted,
      title: title,
      text: text,
      action: label == null || onAction == null
          ? null
          : FilledButton(
              onPressed: onAction,
              style: CorrectionButtons.primary(),
              child: Text(label),
            ),
    );
  }
}

/// Isi bersama ErrorView dan EmptyState: kotak ikon, judul, teks, dan tombol selebar kartu.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.text = '',
    this.action,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: CorrectionDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: CorrectionSizes.gapMd),
          Text(title, style: CorrectionText.cardTitle),
          if (text.isNotEmpty) ...[
            const SizedBox(height: CorrectionSizes.gapXs),
            Text(text, style: CorrectionText.bodyMuted),
          ],
          if (action != null) ...[
            const SizedBox(height: CorrectionSizes.gapMd),
            action,
          ],
        ],
      ),
    );
  }
}

/// Toast sukses gelap berikon di dalam halaman (Figma 285:8542), mis. di halaman "Pengajuan berhasil dikirim".
class CorrectionToast extends StatelessWidget {
  const CorrectionToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: CorrectionColors.ink,
          borderRadius: CorrectionSizes.controlRadius,
        ),
        child: _ToastRow(message: message, success: true),
      ),
    );
  }
}

/// Pesan singkat sebagai SnackBar mengambang bergaya toast yang sama. success false (galat): ikon info.
void showToast(
  BuildContext context,
  String message, {
  bool success = true,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CorrectionColors.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: CorrectionSizes.controlRadius,
        ),
        content: _ToastRow(message: message, success: success),
        action: action,
      ),
    );
}

class _ToastRow extends StatelessWidget {
  const _ToastRow({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          success ? Icons.check_circle_outline : Icons.info_outline,
          size: 22,
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
