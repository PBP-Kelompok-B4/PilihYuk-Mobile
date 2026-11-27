import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Empat kartu statistik, label dan warna sama dengan /antrean/ di situs web.
class QueueStatsGrid extends StatelessWidget {
  const QueueStatsGrid({
    super.key,
    required this.stats,
    required this.shelfAvailable,
  });

  final QueueStats stats;
  final bool shelfAvailable;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        icon: Icons.inbox_outlined,
        background: CorrectionColors.accentSoft,
        foreground: CorrectionColors.accentText,
        value: formatThousands(stats.incompleteProducts),
        title: 'Menunggu kontribusi',
        caption: 'produk dengan data kosong',
      ),
      StatCard(
        icon: Icons.calendar_today_outlined,
        background: CorrectionColors.secondary,
        foreground: CorrectionColors.ink,
        value: formatThousands(stats.submittedLast7Days),
        title: 'Diajukan minggu ini',
        caption: 'pengajuan 7 hari terakhir',
      ),
      StatCard(
        icon: Icons.check_circle_outline,
        background: CorrectionColors.soft,
        foreground: CorrectionColors.primary,
        value: formatThousands(stats.approved),
        title: 'Disetujui',
        caption: 'data berhasil dilengkapi',
      ),
      StatCard(
        icon: Icons.layers_outlined,
        background: CorrectionColors.leaf,
        foreground: CorrectionColors.primary,
        value: shelfAvailable ? formatTimes(stats.shelfAverage) : '—',
        title: 'Rata-rata di shelf',
        caption: shelfAvailable
            ? 'kemunculan per produk'
            : 'data shelf belum tersedia',
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: CorrectionSizes.gapXs),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: CorrectionSizes.gapXs),
                  Expanded(child: cards[i + 1]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Kartu statistik seperti _stat_card.html: kotak ikon, angka, judul, dan keterangan (juga dipakai Moderasi Data).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.value,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String value;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CorrectionSizes.gapSm),
      decoration: CorrectionDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: foreground),
          ),
          const SizedBox(height: CorrectionSizes.gapXs),
          // Angka panjang mengecil, tidak terpotong ke baris baru, di kartu sempit atau huruf besar.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: CorrectionText.stat),
          ),
          Text(title, style: CorrectionText.label),
          Text(caption, style: CorrectionText.caption),
        ],
      ),
    );
  }
}

/// Satu produk di antrean: gambar, nama, merek · isi, data yang kurang, shelf, status, dan "Lengkapi Data".
class QueueProductCard extends StatelessWidget {
  const QueueProductCard({
    super.key,
    required this.product,
    required this.onContribute,
  });

  final QueueProduct product;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CorrectionSizes.gapSm),
      padding: const EdgeInsets.all(CorrectionSizes.gapMd),
      decoration: CorrectionDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(url: product.imageUrl),
              const SizedBox(width: CorrectionSizes.gapSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName.trim().isEmpty
                          ? 'Produk tanpa nama'
                          : product.productName,
                      style: CorrectionText.itemTitle,
                    ),
                    if (product.subtitle.isNotEmpty)
                      Text(product.subtitle, style: CorrectionText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CorrectionSizes.gapSm),
          const Text('Data yang kurang:', style: CorrectionText.caption),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in product.missing)
                _MissingChip(label: entry.label),
            ],
          ),
          const SizedBox(height: CorrectionSizes.gapSm),
          Wrap(
            spacing: CorrectionSizes.gapSm,
            runSpacing: CorrectionSizes.gapXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QueueStatusChip(
                status: product.status,
                label: product.statusLabel,
              ),
              if (product.shelfCount case final count?)
                Text(
                  'Ada di ${formatThousands(count)} shelf',
                  style: CorrectionText.caption,
                ),
            ],
          ),
          const SizedBox(height: CorrectionSizes.gapSm),
          FilledButton.icon(
            onPressed: onContribute,
            style: CorrectionButtons.tonal,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Lengkapi Data'),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(
      Icons.image_outlined,
      color: CorrectionColors.muted,
    );
    return ClipRRect(
      borderRadius: CorrectionSizes.controlRadius,
      child: Container(
        width: 48,
        height: 48,
        color: CorrectionColors.secondary,
        alignment: Alignment.center,
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CorrectionColors.missing,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: CorrectionColors.missingText,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: CorrectionColors.missingText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Perlu kontribusi" oranye, "Perlu verifikasi" abu, sama dengan situs web.
class QueueStatusChip extends StatelessWidget {
  const QueueStatusChip({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final verification = status == QueueProduct.needsVerification;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: verification
            ? CorrectionColors.secondary
            : CorrectionColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: verification
              ? CorrectionColors.ink
              : CorrectionColors.accentText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
