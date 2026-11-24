import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Empat kartu statistik, label sama dengan /antrean/ di situs web.
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
      _StatCard(
        icon: Icons.inbox_outlined,
        background: CorrectionColors.accentSoft,
        foreground: CorrectionColors.accentText,
        value: formatThousands(stats.incompleteProducts),
        title: 'Menunggu kontribusi',
        caption: 'produk dengan data kosong',
      ),
      _StatCard(
        icon: Icons.calendar_today_outlined,
        background: CorrectionColors.secondary,
        foreground: Colors.black87,
        value: formatThousands(stats.submittedLast7Days),
        title: 'Diajukan minggu ini',
        caption: 'pengajuan 7 hari terakhir',
      ),
      _StatCard(
        icon: Icons.check_circle_outline,
        background: CorrectionColors.soft,
        foreground: CorrectionColors.primary,
        value: formatThousands(stats.approved),
        title: 'Disetujui',
        caption: 'data berhasil dilengkapi',
      ),
      _StatCard(
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
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[i + 1]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: background,
              child: Icon(icon, size: 18, color: foreground),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: textTheme.labelLarge),
            Text(caption, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Satu produk di antrean: gambar, nama, merek · isi, data yang kurang, shelf, dan status.
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(url: product.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName.trim().isEmpty
                            ? 'Produk tanpa nama'
                            : product.productName,
                        style: textTheme.titleMedium,
                      ),
                      if (product.subtitle.isNotEmpty)
                        Text(product.subtitle, style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Data yang kurang:', style: textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in product.missing)
                  _MissingChip(label: entry.label),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                QueueStatusChip(
                  status: product.status,
                  label: product.statusLabel,
                ),
                if (product.shelfCount != null)
                  Text(
                    'Ada di ${formatThousands(product.shelfCount!)} shelf',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onContribute,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Lengkapi Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.image_outlined, color: Colors.black45);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
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
          Text(
            label,
            style: const TextStyle(
              color: CorrectionColors.missingText,
              fontSize: 12,
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
          color: verification ? Colors.black87 : CorrectionColors.accentText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
