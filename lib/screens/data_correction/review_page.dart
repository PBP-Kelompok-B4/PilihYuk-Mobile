import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

const noteRequiredMessage = 'Tulis alasan penolakan untuk pengaju.';

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

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      _toast(result.message);
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
      _toast(error.needsLogin ? sessionEndedMessage : error.message);
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
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error is ApiError &&
              (error.status == 403 || error.status == 404)) {
            return ListView(
              padding: const EdgeInsets.all(20),
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
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CorrectionColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CorrectionColors.border),
          ),
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
              const SizedBox(height: 12),
              Text(
                'Sumber: ${row.submittedBy} · ${formatAgo(row.createdAt)}',
                style: const TextStyle(
                  color: CorrectionColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Pengajuan #${row.correctionId} · diajukan ${formatDate(row.createdAt)}',
                style: const TextStyle(
                  color: CorrectionColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CorrectionColors.secondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      product.displayName,
                      style: const TextStyle(
                        color: CorrectionColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        product.subtitle,
                        'Field: ${row.label}',
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: CorrectionColors.muted,
                        fontSize: 12,
                      ),
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
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ValueBox(
                        label: 'Nilai saat ini',
                        value: displayOrUnknown(row.currentDisplay),
                        background: CorrectionColors.secondary,
                        labelColor: CorrectionColors.muted,
                        valueColor: CorrectionColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ValueBox(
                        label: 'Usulan nilai',
                        value: displayOrUnknown(row.proposedDisplay),
                        background: CorrectionColors.soft,
                        labelColor: CorrectionColors.primary,
                        valueColor: CorrectionColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (row.stale) ...[
                const SizedBox(height: 12),
                _StaleWarning(old: displayOrUnknown(row.oldDisplay)),
              ],
              const SizedBox(height: 16),
              if (row.isPending) ...[
                const Text(
                  'Catatan untuk pengaju',
                  style: TextStyle(
                    color: CorrectionColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
                  decoration: InputDecoration(
                    helperText: 'Wajib diisi saat menolak, opsional saat menyetujui. Catatan terlihat oleh pengaju.',
                    helperMaxLines: 3,
                    errorText: _noteError,
                    errorMaxLines: 3,
                    filled: true,
                    fillColor: CorrectionColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: CorrectionColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Item ini sudah ditinjau (${row.statusLabel.toLowerCase()}).',
                        style: const TextStyle(
                          color: CorrectionColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (row.reviewNote.isNotEmpty)
                        Text('Catatan kurator: ${row.reviewNote}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (row.isPending) ...[
          const SizedBox(height: 20),
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
            const SizedBox(height: 12),
          ],
          _ActionButton(
            label: 'Tolak',
            icon: Icons.close,
            color: CorrectionColors.error,
            busy: _sending == CorrectionStatus.rejected,
            onPressed: busy ? null : () => _reject(row),
          ),
          if (!product.isActive) ...[
            const SizedBox(height: 8),
            const Text(
              'Usulan untuk produk nonaktif hanya bisa ditolak.',
              style: TextStyle(color: CorrectionColors.muted, fontSize: 12),
            ),
          ],
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali ke antrean'),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
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
      decoration: BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
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
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
