import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Detail satu pengajuan milik sendiri. initial dipakai apa adanya (mis. balasan 201); tanpa initial,
/// data dimuat dari GET mine/{id}/. justSubmitted menampilkan keadaan "Pengajuan berhasil dikirim".
/// Ditutup dengan hasil true bila pengajuan berubah (ditarik atau ternyata sudah ditinjau), supaya daftar dimuat ulang.
class CorrectionDetailPage extends StatefulWidget {
  const CorrectionDetailPage({
    super.key,
    required this.correctionId,
    this.initial,
    this.justSubmitted = false,
  });

  final int correctionId;
  final Correction? initial;
  final bool justSubmitted;

  @override
  State<CorrectionDetailPage> createState() => _CorrectionDetailPageState();
}

class _CorrectionDetailPageState extends State<CorrectionDetailPage> {
  late Future<Correction> _correction;
  bool _withdrawing = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _correction = initial == null ? _load() : Future.value(initial);
  }

  Future<Correction> _load() =>
      CorrectionApi(context.read<CookieRequest>()).detail(widget.correctionId);

  void _reload() {
    setState(() {
      _correction = _load();
    });
  }

  Future<void> _withdraw(Correction correction) async {
    final confirmed = await confirmWithdraw(context, correction);
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _withdrawing = true;
    });
    final outcome = await withdrawCorrection(
      CorrectionApi(context.read<CookieRequest>()),
      correction.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _withdrawing = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(outcome.message)));
    if (outcome.gone) {
      Navigator.pop(context, true);
    } else if (outcome.reload) {
      setState(() {
        _changed = true;
        _correction = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Setelah status berubah, tombol kembali tetap menutup halaman tetapi dengan hasil true.
    return PopScope<bool>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Antrean Data')),
        body: FutureBuilder<Correction>(
          future: _correction,
          initialData: widget.initial,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = snapshot.error;
            if (error != null) {
              return ErrorView(
                message: error is ApiError
                    ? error.message
                    : 'Gagal memuat pengajuan.',
                onRetry: _reload,
              );
            }
            return _detailView(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _detailView(Correction correction) {
    final submitted = widget.justSubmitted;
    // Sama dengan web: "Nilai saat ini" hanya benar tepat setelah mengajukan.
    final oldLabel = submitted ? 'Nilai saat ini' : 'Nilai saat diajukan';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pengajuan Saya › Pengajuan #${correction.id}',
          style: const TextStyle(color: CorrectionColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Text(
          submitted ? 'Pengajuan berhasil dikirim' : 'Detail pengajuan',
          style: const TextStyle(
            color: CorrectionColors.ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (submitted) ...[
          const SizedBox(height: 8),
          const Text(
            'Terima kasih sudah membantu melengkapi data. Kurator akan meninjau setiap usulan.',
            style: TextStyle(color: CorrectionColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          const _SuccessToast(),
        ],
        const SizedBox(height: 24),
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
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CorrectionStatusChip(
                    status: correction.status,
                    label: correction.statusLabel,
                  ),
                  Text(
                    'Pengajuan #${correction.id} · diajukan ${formatDate(correction.createdAt)}',
                    style: const TextStyle(
                      color: CorrectionColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                correction.product.displayName,
                style: const TextStyle(
                  color: CorrectionColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (correction.product.subtitle.isNotEmpty)
                Text(
                  correction.product.subtitle,
                  style: const TextStyle(
                    color: CorrectionColors.muted,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              for (final item in correction.items)
                _ItemView(item: item, oldLabel: oldLabel),
              if (correction.status == CorrectionStatus.pending) ...[
                const SizedBox(height: 4),
                const PendingNotice(),
              ],
              if (!submitted && correction.isWithdrawable) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: WithdrawButton(
                    onPressed: () => _withdraw(correction),
                    busy: _withdrawing,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (submitted) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: CorrectionColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Kembali ke Antrean Data'),
          ),
        ],
      ],
    );
  }
}

class _SuccessToast extends StatelessWidget {
  const _SuccessToast();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CorrectionColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 22, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pengajuan berhasil dikirim',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, required this.oldLabel});

  final CorrectionItem item;
  final String oldLabel;

  @override
  Widget build(BuildContext context) {
    final old = item.oldDisplay;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CorrectionColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: CorrectionColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CorrectionStatusChip(
                status: item.status,
                label: item.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DataRow(
            label: oldLabel,
            value: old == null
                ? const UnknownChip()
                : Text(
                    old,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 8),
          _DataRow(
            label: 'Usulan nilai',
            value: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: displayOrUnknown(item.proposedDisplay),
                    style: const TextStyle(
                      color: CorrectionColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.isPending)
                    const TextSpan(
                      text: ' · belum disetujui',
                      style: TextStyle(
                        color: CorrectionColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (item.hasNote) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan kurator: ${item.reviewNote}',
              style: const TextStyle(
                color: CorrectionColors.ink2,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label di kiri, nilai di kanan (baris data di Figma).
class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: CorrectionColors.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }
}
