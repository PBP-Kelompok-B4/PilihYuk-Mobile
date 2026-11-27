import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Pengajuan Saya: koreksi milik pengguna yang sedang masuk (GET mine/?page=), terbaru dulu, 10 per halaman.
/// Isinya sama dengan /antrean/saya/ di web. Setelah menarik pengajuan, halaman dimuat ulang dari server.
class MyCorrectionsPage extends StatefulWidget {
  const MyCorrectionsPage({super.key});

  @override
  State<MyCorrectionsPage> createState() => _MyCorrectionsPageState();
}

class _MyCorrectionsPageState extends State<MyCorrectionsPage> {
  int _page = 1;
  int? _withdrawing; // id pengajuan yang sedang ditarik
  late Future<CorrectionList> _list;

  @override
  void initState() {
    super.initState();
    _list = _fetch();
  }

  Future<CorrectionList> _fetch() async {
    final list = await CorrectionApi(context.read<CookieRequest>())
        .mine(page: _page);
    _page = list.page; // halaman yang kosong setelah ditarik diganti server dengan halaman terakhir
    return list;
  }

  Future<void> _reload() {
    setState(() {
      _list = _fetch();
    });
    return _list.then<void>((_) {}, onError: (Object _) {});
  }

  void _go(int page) {
    _page = page;
    _reload();
  }

  Future<void> _openDetail(Correction correction) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CorrectionDetailPage(
          correctionId: correction.id,
          initial: correction,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
    }
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
      _withdrawing = correction.id;
    });
    final outcome = await withdrawCorrection(
      CorrectionApi(context.read<CookieRequest>()),
      correction.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _withdrawing = null;
    });
    showToast(context, outcome.message, success: outcome.success);
    if (outcome.reload) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Saya')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<CorrectionList>(
          future: _list,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            if (loading && !snapshot.hasData) {
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
            return _listView(snapshot.data!, loading);
          },
        ),
      ),
    );
  }

  Widget _listView(CorrectionList list, bool loading) {
    final previous = list.previousPage;
    final next = list.nextPage;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(CorrectionSizes.inset),
      children: [
        if (loading)
          const LinearProgressIndicator(color: CorrectionColors.primary),
        const Text(
          'Status koreksi yang kamu ajukan. Pengajuan yang belum ditinjau sama sekali masih bisa ditarik.',
          style: CorrectionText.bodyMuted,
        ),
        const SizedBox(height: CorrectionSizes.gapMd),
        if (list.results.isEmpty)
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Belum ada pengajuan.',
            text: 'Bantu lengkapi data produk yang masih kosong dari Antrean Data.',
            actionLabel: 'Buka Antrean Data',
            onAction: () => Navigator.maybePop(context),
          )
        else ...[
          for (final correction in list.results)
            _CorrectionCard(
              key: ValueKey('correction-${correction.id}'),
              correction: correction,
              onOpen: () => _openDetail(correction),
              onWithdraw: _withdrawing == null
                  ? () => _withdraw(correction)
                  : null,
              withdrawing: _withdrawing == correction.id,
            ),
          if (list.numPages > 1)
            PageNav(
              page: list.page,
              numPages: list.numPages,
              onPrevious: previous == null ? null : () => _go(previous),
              onNext: next == null ? null : () => _go(next),
            ),
        ],
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    super.key,
    required this.correction,
    required this.onOpen,
    required this.onWithdraw,
    this.withdrawing = false,
  });

  final Correction correction;
  final VoidCallback onOpen;
  final VoidCallback?
  onWithdraw; // null selama ada pengajuan lain yang sedang ditarik
  final bool withdrawing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CorrectionSizes.gapMd),
      padding: const EdgeInsets.all(18),
      decoration: CorrectionDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chip dan nomor di atas nama, seperti di halaman detail: chip yang panjang turun baris, tidak meluap.
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
          const SizedBox(height: CorrectionSizes.gapXs),
          Text(correction.product.displayName, style: CorrectionText.cardTitle),
          const SizedBox(height: CorrectionSizes.gapXs),
          for (final item in correction.items) _ItemRow(item: item),
          const SizedBox(height: CorrectionSizes.gapSm),
          Wrap(
            spacing: CorrectionSizes.gapSm,
            runSpacing: CorrectionSizes.gapXs,
            children: [
              OutlinedButton(
                onPressed: onOpen,
                style: CorrectionButtons.outlined(),
                child: const Text('Lihat detail'),
              ),
              if (correction.isWithdrawable)
                WithdrawButton(onPressed: onWithdraw, busy: withdrawing),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu field: label dan chip, "nilai lama → usulan", lalu catatan kurator bila ada.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CorrectionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CorrectionColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.label, style: CorrectionText.label)),
              const SizedBox(width: CorrectionSizes.gapXs),
              CorrectionStatusChip(
                status: item.status,
                label: item.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: CorrectionText.meta,
              children: [
                TextSpan(text: '${displayOrUnknown(item.oldDisplay)} → '),
                TextSpan(
                  text: displayOrUnknown(item.proposedDisplay),
                  style: const TextStyle(
                    color: CorrectionColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (item.hasNote) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan kurator: ${item.reviewNote}',
              style: CorrectionText.caption.copyWith(
                color: CorrectionColors.ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
