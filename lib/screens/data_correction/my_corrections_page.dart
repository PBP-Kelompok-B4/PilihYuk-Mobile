import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_detail_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Pengajuan Saya: koreksi milik pengguna yang sedang masuk (GET mine/?page=), terbaru dulu, 10 per halaman.
/// Isinya sama dengan /antrean/saya/ di web.
class MyCorrectionsPage extends StatefulWidget {
  const MyCorrectionsPage({super.key});

  @override
  State<MyCorrectionsPage> createState() => _MyCorrectionsPageState();
}

class _MyCorrectionsPageState extends State<MyCorrectionsPage> {
  int _page = 1;
  late Future<CorrectionList> _list;

  @override
  void initState() {
    super.initState();
    _list = _fetch();
  }

  Future<CorrectionList> _fetch() =>
      CorrectionApi(context.read<CookieRequest>()).mine(page: _page);

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

  void _openDetail(Correction correction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CorrectionDetailPage(
          correctionId: correction.id,
          initial: correction,
        ),
      ),
    );
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
            return _listView(snapshot.data!, loading);
          },
        ),
      ),
    );
  }

  Widget _listView(CorrectionList list, bool loading) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (loading) const LinearProgressIndicator(),
        const Text(
          'Status koreksi yang kamu ajukan. Pengajuan yang belum ditinjau sama sekali masih bisa ditarik.',
          style: TextStyle(color: CorrectionColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
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
              correction: correction,
              onOpen: () => _openDetail(correction),
            ),
          if (list.numPages > 1) _pagination(list),
        ],
      ],
    );
  }

  Widget _pagination(CorrectionList list) {
    final previous = list.previousPage;
    final next = list.nextPage;
    return Row(
      children: [
        TextButton.icon(
          onPressed: previous == null ? null : () => _go(previous),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Sebelumnya'),
        ),
        Expanded(
          child: Text(
            'Halaman ${list.page} dari ${list.numPages}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CorrectionColors.muted, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: next == null ? null : () => _go(next),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Berikutnya'), Icon(Icons.chevron_right)],
          ),
        ),
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction, required this.onOpen});

  final Correction correction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CorrectionColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CorrectionColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correction.product.displayName,
                      style: const TextStyle(
                        color: CorrectionColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pengajuan #${correction.id} · diajukan ${formatDate(correction.createdAt)}',
                      style: const TextStyle(
                        color: CorrectionColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CorrectionStatusChip(
                status: correction.status,
                label: correction.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in correction.items) _ItemRow(item: item),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: CorrectionColors.ink,
                side: const BorderSide(color: CorrectionColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Lihat detail'),
            ),
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
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: CorrectionColors.ink,
                    fontSize: 14,
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
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: CorrectionColors.muted,
                fontSize: 14,
              ),
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
              style: const TextStyle(
                color: CorrectionColors.ink2,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
