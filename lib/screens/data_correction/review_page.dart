import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

const noteRequiredMessage = 'Tulis alasan penolakan untuk pengaju.';

/// Lebar minimal satu kotak nilai pada ukuran huruf normal.
const _valueBoxWidth = 123.0;

/// Review satu item koreksi: GET moderation/items/{id}/ (nilai produk selalu segar), lalu PATCH approved atau
/// rejected. Ditutup dengan true bila status item berubah, supaya antrean moderasi dimuat ulang.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.itemId});

  final int itemId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _note = TextEditingController();
  late Future<ModerationRow> _item;
  String? _sending; // status yang sedang dikirim
  String? _noteError;

  @override
  void initState() {
    super.initState();
    _item = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<ModerationRow> _load() =>
      CorrectionApi(context.read<CookieRequest>())
          .moderationItem(widget.itemId);

  void _reload() {
    setState(() {
      _item = _load();
    });
  }

  /// Tolak: catatan wajib (dicek di sini dulu), lalu konfirmasi seperti dialog web.
  Future<void> _reject(ModerationRow row) async {
    if (_note.text.trim().isEmpty) {
      setState(() {
        _noteError = noteRequiredMessage;
      });
      return;
    }
    final name = row.product.productName.trim();
    final confirmed = await showConfirmSheet(
      context,
      title: 'Tolak usulan ini?',
      message:
          'Usulan ${row.label} untuk ${name.isEmpty ? 'produk ini' : name} tidak dipakai. Catatanmu dikirim ke pengaju.',
      confirmLabel: 'Tolak Usulan',
      icon: Icons.close,
    );
    if (!confirmed) {
      return;
    }
    await _send(row, CorrectionStatus.rejected);
  }

  Future<void> _send(ModerationRow row, String status) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _sending = status;
      _noteError = null;
    });
    try {
      final result = await CorrectionApi(context.read<CookieRequest>())
          .review(row.id, status, note: _note.text.trim());
      if (!mounted) {
        return;
      }
      showToast(context, result.message);
      Navigator.pop(context, true);
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = null;
        _noteError = error.fieldError('review_note');
      });
      if (_noteError != null) {
        return;
      }
      showToast(
        context,
        error.needsLogin ? sessionEndedMessage : error.message,
        success: false,
      );
      if (error.code == 'already_reviewed' || error.status == 404) {
        Navigator.pop(context, true);
      } else if (error.status == 409) {
        _reload(); // mis. produk baru saja dinonaktifkan
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review pengajuan')),
      body: FutureBuilder<ModerationRow>(
        future: _item,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          final error = snapshot.error;
          if (error is ApiError &&
              (error.status == 403 || error.status == 404)) {
            return ListView(
              padding: const EdgeInsets.all(CorrectionSizes.inset),
              children: [
                EmptyState(
                  icon: error.status == 403
                      ? Icons.lock_outline
                      : Icons.search_off,
                  title: error.needsLogin ? sessionEndedMessage : error.message,
                  actionLabel: 'Kembali ke antrean',
                  onAction: () => Navigator.pop(context, true),
                ),
              ],
            );
          }
          if (error != null) {
            return ErrorView(
              message: error is ApiError ? error.message : 'Gagal memuat item.',
              onRetry: _reload,
            );
          }
          return _reviewView(snapshot.data!);
        },
      ),
    );
  }

  Widget _reviewView(ModerationRow row) {
    final product = row.product;
    final busy = _sending != null;
    return ListView(
      padding: const EdgeInsets.all(CorrectionSizes.inset),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: CorrectionDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CorrectionStatusChip(
                  status: row.status,
                  label: row.statusLabel,
                ),
              ),
              const SizedBox(height: CorrectionSizes.gapSm),
              Text(
                'Sumber: ${row.submittedBy} · ${formatAgo(row.createdAt)}',
                style: CorrectionText.value,
              ),
              Text(
                'Pengajuan #${row.correctionId} · diajukan ${formatDate(row.createdAt)}',
                style: CorrectionText.caption,
              ),
              const SizedBox(height: CorrectionSizes.gapMd),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: CorrectionDecorations.field,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(product.displayName, style: CorrectionText.itemTitle),
                    Text(
                      [
                        product.subtitle,
                        'Field: ${row.label}',
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: CorrectionText.caption,
                    ),
                    if (!product.isActive) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Produk ini sudah tidak aktif.',
                        style: TextStyle(
                          color: CorrectionColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: CorrectionSizes.gapSm),
              _values(row),
              if (row.stale) ...[
                const SizedBox(height: CorrectionSizes.gapSm),
                _StaleWarning(old: displayOrUnknown(row.oldDisplay)),
              ],
              const SizedBox(height: CorrectionSizes.gapMd),
              if (row.isPending) ...[
                const Text(
                  'Catatan untuk pengaju',
                  style: CorrectionText.label,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _note,
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: (_) {
                    if (_noteError != null) {
                      setState(() {
                        _noteError = null;
                      });
                    }
                  },
                  decoration: CorrectionInputs.decoration(
                    helper: 'Wajib diisi saat menolak, opsional saat menyetujui. Catatan terlihat oleh pengaju.',
                    error: _noteError,
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: CorrectionDecorations.field,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Item ini sudah ditinjau (${row.statusLabel.toLowerCase()}).',
                        style: CorrectionText.value,
                      ),
                      if (row.reviewNote.isNotEmpty)
                        Text(
                          'Catatan kurator: ${row.reviewNote}',
                          style: CorrectionText.meta.copyWith(
                            color: CorrectionColors.ink2,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (row.isPending) ...[
          const SizedBox(height: CorrectionSizes.gapLg),
          if (product.isActive) ...[
            _ActionButton(
              label: 'Setujui',
              icon: Icons.check,
              color: CorrectionColors.primary,
              busy: _sending == CorrectionStatus.approved,
              onPressed: busy
                  ? null
                  : () => _send(row, CorrectionStatus.approved),
            ),
            const SizedBox(height: CorrectionSizes.gapSm),
          ],
          _ActionButton(
            label: 'Tolak',
            icon: Icons.close,
            color: CorrectionColors.error,
            busy: _sending == CorrectionStatus.rejected,
            onPressed: busy ? null : () => _reject(row),
          ),
          if (!product.isActive) ...[
            const SizedBox(height: CorrectionSizes.gapXs),
            const Text(
              'Usulan untuk produk nonaktif hanya bisa ditolak.',
              style: CorrectionText.caption,
            ),
          ],
        ],
        const SizedBox(height: CorrectionSizes.gapXs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : () => Navigator.maybePop(context),
            style: TextButton.styleFrom(
              foregroundColor: CorrectionColors.ink,
              minimumSize: const Size(0, CorrectionSizes.touchTarget),
            ),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali ke antrean'),
          ),
        ),
      ],
    );
  }

  /// Nilai saat ini dan usulan berdampingan seperti panel review web. Di layar sempit atau huruf besar
  /// keduanya disusun ke bawah, supaya "Tidak diketahui" dan angka panjang tidak terpotong.
  Widget _values(ModerationRow row) {
    final current = _ValueBox(
      label: 'Nilai saat ini',
      value: displayOrUnknown(row.currentDisplay),
      background: CorrectionColors.secondary,
      labelColor: CorrectionColors.muted,
      valueColor: CorrectionColors.ink,
    );
    final proposed = _ValueBox(
      label: 'Usulan nilai',
      value: displayOrUnknown(row.proposedDisplay),
      background: CorrectionColors.soft,
      labelColor: CorrectionColors.primary,
      valueColor: CorrectionColors.primary,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Faktor ukuran huruf pada teks 18 px (nilai di kotak); 1,0 pada ukuran normal.
        final scale = MediaQuery.textScalerOf(context).scale(18) / 18;
        final rowWidth = (2 * _valueBoxWidth + CorrectionSizes.gapSm) * scale;
        if (constraints.maxWidth < rowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              current,
              const SizedBox(height: CorrectionSizes.gapSm),
              proposed,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: current),
              const SizedBox(width: CorrectionSizes.gapSm),
              Expanded(child: proposed),
            ],
          ),
        );
      },
    );
  }
}

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.label,
    required this.value,
    required this.background,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color background;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: CorrectionSizes.controlRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: CorrectionText.caption.copyWith(color: labelColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: CorrectionText.cardTitle.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _StaleWarning extends StatelessWidget {
  const _StaleWarning({required this.old});

  final String old;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: CorrectionSizes.controlRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: CorrectionColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nilai produk sudah berubah sejak diajukan (saat diajukan: $old). Menyetujui akan menimpa nilai sekarang.',
              style: const TextStyle(
                color: CorrectionColors.warning,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi selebar layar (tinggi 48). busy menampilkan indikator.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: CorrectionButtons.primary(background: color),
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}
