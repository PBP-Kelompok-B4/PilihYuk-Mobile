import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/queue_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/review_page.dart';

/// Moderasi Data untuk kurator. Tab antrean dan semua: item per field dari GET moderation/ (20 per halaman);
/// tab panduan: GET moderation/guide/. Isinya sama dengan /moderasi/ di web.
class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  String _tab = ModerationQueue.antrean;
  String? _field;
  String? _status; // hanya di tab semua
  int _page = 1;
  late Future<ModerationQueue> _queue;
  Future<List<FieldGuideEntry>>? _guide;

  CorrectionApi get _api => CorrectionApi(context.read<CookieRequest>());

  @override
  void initState() {
    super.initState();
    _queue = _fetch();
  }

  /// Tab panduan memakai daftar bawaan (antrean) hanya untuk statistik dan label tab.
  Future<ModerationQueue> _fetch() async {
    final queue = await _api.moderation(
      tab: _tab == ModerationQueue.semua ? _tab : null,
      field: _field,
      status: _status,
      page: _page,
    );
    _page = queue.page;
    return queue;
  }

  Future<void> _reload() {
    setState(() {
      _queue = _fetch();
      if (_tab == ModerationQueue.panduan) {
        _guide = _api.guide();
      }
    });
    return _queue.then<void>((_) {}, onError: (Object _) {});
  }

  /// Pindah tab mengosongkan filter, seperti tautan tab di web.
  void _selectTab(String tab) {
    setState(() {
      _tab = tab;
      _field = null;
      _status = null;
      _page = 1;
      if (tab == ModerationQueue.panduan) {
        _guide ??= _api.guide();
      } else {
        _queue = _fetch();
      }
    });
  }

  void _filter({String? field, String? status}) {
    setState(() {
      _field = field;
      _status = status;
      _page = 1;
      _queue = _fetch();
    });
  }

  void _go(int page) {
    setState(() {
      _page = page;
      _queue = _fetch();
    });
  }

  void _retryGuide() {
    setState(() {
      _guide = _api.guide();
    });
  }

  /// ReviewPage kembali dengan true bila item sudah disetujui atau ditolak; daftar lalu dimuat ulang.
  Future<void> _review(ModerationRow row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReviewPage(itemId: row.id)),
    );
    if (changed == true && mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderasi Data')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<ModerationQueue>(
          future: _queue,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            if (loading && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = snapshot.error;
            if (error is ApiError && error.status == 403) {
              return _forbidden(error);
            }
            if (error != null) {
              return ErrorView(
                message: error is ApiError
                    ? error.message
                    : 'Gagal memuat antrean moderasi.',
                onRetry: _reload,
              );
            }
            return _pageView(snapshot.data!, loading);
          },
        ),
      ),
    );
  }

  /// 403: bukan kurator, atau sesi sudah habis.
  Widget _forbidden(ApiError error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        EmptyState(
          icon: Icons.lock_outline,
          title: error.needsLogin ? sessionEndedMessage : error.message,
          text: 'Moderasi Data hanya bisa dibuka dengan akun kurator.',
          actionLabel: 'Kembali',
          onAction: () => Navigator.maybePop(context),
        ),
      ],
    );
  }

  Widget _pageView(ModerationQueue queue, bool loading) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (loading) const LinearProgressIndicator(),
        const Text(
          'Tinjau koreksi data produk hasil kontribusi pengguna. Setujui atau tolak per field.',
          style: TextStyle(color: CorrectionColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        _stats(queue.stats),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in queue.tabOptions)
              ChoiceChip(
                label: Text(option.label),
                selected: option.key == _tab,
                onSelected: (_) {
                  if (option.key != _tab) {
                    _selectTab(option.key);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_tab == ModerationQueue.panduan)
          _guideView()
        else
          ..._listChildren(queue),
      ],
    );
  }

  Widget _stats(ModerationStats stats) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.schedule,
              background: CorrectionColors.secondary,
              foreground: CorrectionColors.ink,
              value: formatThousands(stats.pending),
              title: 'Menunggu review',
              caption: 'item koreksi',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              icon: Icons.check_circle_outline,
              background: CorrectionColors.soft,
              foreground: CorrectionColors.primary,
              value: formatThousands(stats.approved),
              title: 'Disetujui',
              caption: 'total item',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              icon: Icons.cancel_outlined,
              background: CorrectionColors.rejectedSoft,
              foreground: CorrectionColors.rejectedText,
              value: formatThousands(stats.rejected),
              title: 'Ditolak',
              caption: 'total item',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _listChildren(ModerationQueue queue) {
    final all = _tab == ModerationQueue.semua;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              all ? 'Semua pengajuan' : 'Antrean pengajuan',
              style: const TextStyle(
                color: CorrectionColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${formatThousands(queue.count)} item',
            style: const TextStyle(color: CorrectionColors.muted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('Semua field'),
            selected: queue.field == null,
            onSelected: (_) => _filter(status: queue.status),
          ),
          for (final option in queue.fieldOptions)
            ChoiceChip(
              label: Text(option.label),
              selected: option.key == queue.field,
              onSelected: (_) =>
                  _filter(field: option.key, status: queue.status),
            ),
        ],
      ),
      if (queue.statusOptions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Semua status'),
              selected: queue.status == null,
              onSelected: (_) => _filter(field: queue.field),
            ),
            for (final option in queue.statusOptions)
              ChoiceChip(
                label: Text(option.label),
                selected: option.key == queue.status,
                onSelected: (_) =>
                    _filter(field: queue.field, status: option.key),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      if (queue.results.isEmpty)
        all
            ? const EmptyState(
                icon: Icons.search,
                title: 'Belum ada item yang cocok dengan filter ini.',
                text: 'Coba pilih field atau status lain.',
              )
            : const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Tidak ada pengajuan yang menunggu review.',
                text: 'Semua usulan sudah ditinjau. Usulan baru akan muncul di sini.',
              )
      else ...[
        for (final row in queue.results)
          _ModerationCard(
            key: ValueKey('item-${row.id}'),
            row: row,
            onReview: () => _review(row),
          ),
        if (queue.numPages > 1) _pagination(queue),
      ],
    ];
  }

  Widget _pagination(ModerationQueue queue) {
    final previous = queue.previousPage;
    final next = queue.nextPage;
    return Row(
      children: [
        TextButton.icon(
          onPressed: previous == null ? null : () => _go(previous),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Sebelumnya'),
        ),
        Expanded(
          child: Text(
            'Halaman ${queue.page} dari ${queue.numPages}',
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

  Widget _guideView() {
    return FutureBuilder<List<FieldGuideEntry>>(
      future: _guide,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return Column(
            children: [
              Text(
                error is ApiError ? error.message : 'Gagal memuat panduan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _retryGuide,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          );
        }
        return _FieldGuide(fields: snapshot.data!);
      },
    );
  }
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({super.key, required this.row, required this.onReview});

  final ModerationRow row;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: CorrectionColors.muted, fontSize: 14);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CorrectionColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CorrectionColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            row.product.displayName,
            style: const TextStyle(
              color: CorrectionColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (row.product.subtitle.isNotEmpty)
            Text(
              row.product.subtitle,
              style: const TextStyle(
                color: CorrectionColors.muted,
                fontSize: 12,
              ),
            ),
          Text(
            '${row.submittedBy} · ${formatAgo(row.createdAt)}',
            style: const TextStyle(color: CorrectionColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: CorrectionColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              children: [
                const TextSpan(
                  text: 'Field: ',
                  style: TextStyle(
                    color: CorrectionColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(text: row.label),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saat ini: ${displayOrUnknown(row.currentDisplay)}',
            style: muted,
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: muted,
              children: [
                const TextSpan(text: 'Usulan: '),
                TextSpan(
                  text: displayOrUnknown(row.proposedDisplay),
                  style: const TextStyle(
                    color: CorrectionColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    CorrectionStatusChip(
                      status: row.status,
                      label: row.statusLabel,
                    ),
                    if (row.stale) const _StaleChip(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onReview,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: CorrectionColors.soft,
                  foregroundColor: CorrectionColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(row.isPending ? 'Review' : 'Lihat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Penanda item yang nilai produknya sudah berubah sejak diajukan.
class _StaleChip extends StatelessWidget {
  const _StaleChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CorrectionColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Nilai berubah',
        style: TextStyle(
          color: CorrectionColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Isi tab Panduan field, sama dengan _field_guide.html di web.
class _FieldGuide extends StatelessWidget {
  const _FieldGuide({required this.fields});

  final List<FieldGuideEntry> fields;

  static const _howTo = [
    'Setujui menulis nilai usulan ke produk saat itu juga; catatan boleh dikosongkan.',
    'Tolak tidak mengubah produk dan wajib disertai catatan, karena catatan itu terlihat oleh pengaju.',
    '"Tidak diketahui" berarti kolom produk kosong; angka 0 adalah data yang sah.',
    'Peringatan muncul bila nilai produk sudah berubah sejak diajukan; menyetujui akan menimpa nilai itu.',
    'Item yang sudah ditinjau tidak bisa ditinjau ulang.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CorrectionColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CorrectionColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Panduan field',
            style: TextStyle(
              color: CorrectionColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hanya ${fields.length} field berikut yang bisa dikoreksi pengguna. Aturannya sama dengan pemeriksaan '
            'otomatis saat pengajuan dibuat dan saat disetujui.',
            style: const TextStyle(color: CorrectionColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final field in fields)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: CorrectionColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    field.label,
                    style: const TextStyle(
                      color: CorrectionColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${field.kind} · ${field.fieldName}',
                    style: const TextStyle(
                      color: CorrectionColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final rule in field.rules) _Bullet(rule),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Cara meninjau',
            style: TextStyle(
              color: CorrectionColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in _howTo) _Bullet(line),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(color: CorrectionColors.muted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: CorrectionColors.ink2,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
