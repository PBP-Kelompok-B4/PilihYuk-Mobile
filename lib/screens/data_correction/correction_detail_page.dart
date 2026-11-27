import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/module_navigation.dart';

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
    showToast(context, outcome.message, success: outcome.success);
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
              return const LoadingView();
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
      padding: const EdgeInsets.all(CorrectionSizes.inset),
      children: [
        Text(
          'Pengajuan Saya › Pengajuan #${correction.id}',
          style: CorrectionText.meta,
        ),
        const SizedBox(height: CorrectionSizes.gapMd),
        Text(
          submitted ? 'Pengajuan berhasil dikirim' : 'Detail pengajuan',
          style: CorrectionText.pageTitle,
        ),
        if (submitted) ...[
          const SizedBox(height: CorrectionSizes.gapXs),
          const Text(
            'Terima kasih sudah membantu melengkapi data. Kurator akan meninjau setiap usulan.',
            style: CorrectionText.bodyMuted,
          ),
          const SizedBox(height: CorrectionSizes.gapMd),
          const CorrectionToast(message: 'Pengajuan berhasil dikirim'),
        ],
        const SizedBox(height: CorrectionSizes.gapLg),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: CorrectionDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: CorrectionSizes.gapXs,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CorrectionStatusChip(
                    status: correction.status,
                    label: correction.statusLabel,
                  ),
                  Text(
                    'Pengajuan #${correction.id} · diajukan ${formatDate(correction.createdAt)}',
                    style: CorrectionText.caption,
                  ),
                ],
              ),
              const SizedBox(height: CorrectionSizes.gapSm),
              Text(
                correction.product.displayName,
                style: CorrectionText.cardTitle,
              ),
              if (correction.product.subtitle.isNotEmpty)
                Text(correction.product.subtitle, style: CorrectionText.meta),
              const SizedBox(height: CorrectionSizes.gapSm),
              for (final item in correction.items)
                _ItemView(item: item, oldLabel: oldLabel),
              if (correction.status == CorrectionStatus.pending) ...[
                const SizedBox(height: 4),
                const PendingNotice(),
              ],
              if (!submitted && correction.isWithdrawable) ...[
                const SizedBox(height: CorrectionSizes.gapMd),
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
          const SizedBox(height: CorrectionSizes.gapLg),
          FilledButton(
            onPressed: () => backToQueue(context),
            style: CorrectionButtons.primary(),
            child: const Text('Kembali ke Antrean Data'),
          ),
        ],
      ],
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
                child: Text(item.label, style: CorrectionText.itemTitle),
              ),
              const SizedBox(width: CorrectionSizes.gapXs),
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
                : Text(old, style: CorrectionText.value),
          ),
          const SizedBox(height: CorrectionSizes.gapXs),
          _DataRow(
            label: 'Usulan nilai',
            value: Text.rich(
              TextSpan(
                style: CorrectionText.value,
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
                      style: CorrectionText.caption,
                    ),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (item.hasNote) ...[
            const SizedBox(height: CorrectionSizes.gapXs),
            Text(
              'Catatan kurator: ${item.reviewNote}',
              style: CorrectionText.meta.copyWith(color: CorrectionColors.ink2),
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
        Expanded(child: Text(label, style: CorrectionText.meta)),
        const SizedBox(width: CorrectionSizes.gapSm),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }
}
