import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_api.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_form_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';
import 'package:pilihyuk_mobile/screens/data_correction/moderation_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/module_navigation.dart';
import 'package:pilihyuk_mobile/screens/data_correction/my_corrections_page.dart';
import 'package:pilihyuk_mobile/screens/data_correction/queue_widgets.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

/// Antrean kontribusi: produk yang datanya belum lengkap, dari GET /api/v1/corrections/queue/.
/// Halaman publik, jadi bisa dibuka tanpa masuk.
class DataCorrectionPage extends StatefulWidget {
  const DataCorrectionPage({super.key});

  @override
  State<DataCorrectionPage> createState() => _DataCorrectionPageState();
}

class _DataCorrectionPageState extends State<DataCorrectionPage> {
  String? _sort; // null = urutan bawaan server
  String? _missing; // null = semua jenis data
  int _page = 1;
  late Future<CorrectionQueue> _queue;
  Viewer? _viewer; // hasil me/ terakhir; null = belum ada jawaban atau gagal
  late final CookieRequest _request;
  late final ModuleSession _session;

  // Future dibuat sekali di sini (Tutorial 10), bukan di build.
  @override
  void initState() {
    super.initState();
    _request = context.read<CookieRequest>();
    _session = ModuleSession(_sessionEnded)..attach(_request);
    _queue = _fetch();
    _loadViewer();
  }

  @override
  void dispose() {
    _session.detach(_request);
    super.dispose();
  }

  /// Sesi habis di halaman modul mana pun: sheet login di atas halaman itu. me/ dimuat ulang, masuk lagi atau
  /// tidak, supaya tombol dan gerbang ikut keadaan baru; bila masuk lagi, CorrectionApi mengulang permintaannya.
  Future<bool> _sessionEnded() async {
    final relogged = await handleSessionEnded(context);
    if (mounted) {
      await _loadViewer();
    }
    return relogged;
  }

  /// Status login dan kurator dari GET me/ (KEPUTUSAN F.a), untuk tombol AppBar dan gerbang login.
  Future<void> _loadViewer() async {
    final viewer = await loadViewer(_request);
    if (mounted) {
      setState(() {
        _viewer = viewer;
      });
    }
  }

  Future<CorrectionQueue> _fetch() async {
    final request = context.read<CookieRequest>();
    final url = CorrectionQueue.uri(
      baseUrl,
      sort: _sort,
      missing: _missing,
      page: _page,
    );
    final data = await request.get(url.toString());
    return CorrectionQueue.fromJson(data);
  }

  // Galatnya sudah ditampilkan FutureBuilder, jadi tarik-untuk-muat-ulang cukup menunggu selesai.
  Future<void> _reload() {
    // Kurung kurawal, bukan =>: closure setState tidak boleh mengembalikan Future.
    setState(() {
      _queue = _fetch();
    });
    return _queue.then<void>((_) {}, onError: (Object _) {});
  }

  // Tarik-untuk-muat-ulang juga menanyakan me/ lagi.
  Future<void> _refresh() async {
    await Future.wait([_reload(), _loadViewer()]);
  }

  // Chip dan tombol halaman memakai sort dan missing dari balasan terakhir.
  void _show({required String sort, String? missing, int page = 1}) {
    _sort = sort;
    _missing = missing;
    _page = page;
    _reload();
  }

  /// Gerbang login memakai hasil me/ terakhir. me/ yang gagal ditanyakan lagi saat tombol ditekan;
  /// sesudah masuk lewat sheet, me/ dimuat ulang supaya tombol kurator ikut muncul.
  Future<bool> _ensureLoggedIn() async {
    if (_viewer == null) {
      await _loadViewer();
      if (!mounted) {
        return false;
      }
    }
    final wasLoggedIn = _viewer?.loggedIn ?? false;
    final allowed = await ensureLoggedIn(context, viewer: _viewer);
    if (allowed && !wasLoggedIn && mounted) {
      await _loadViewer();
    }
    return allowed;
  }

  /// Membuka halaman modul. Kalau di sana ada data yang berubah (kirim, tarik, tinjau), antrean dimuat ulang
  /// sekali; untuk form, saat form diganti halaman sukses.
  Future<void> _open(String name, Widget page) async {
    await pushModulePage<Object?>(context, name, page);
    if (mounted && _session.takeChanges()) {
      await _reload();
    }
  }

  Future<void> _contribute(QueueProduct product) async {
    if (!await _ensureLoggedIn()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final focus = [
      for (final entry in product.missing)
        if (entry.correctable) ...entry.fields,
    ];
    await _open(
      'form',
      CorrectionFormPage(productId: product.id, focus: focus),
    );
  }

  Future<void> _openMine() async {
    if (!await _ensureLoggedIn()) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _open('saya', const MyCorrectionsPage());
  }

  // Tombolnya hanya tampil untuk kurator menurut me/; server tetap memeriksa lagi (403 forbidden).
  Future<void> _openModeration() => _open('moderasi', const ModerationPage());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean Data'),
        actions: [
          // Tamu juga melihat tombol ini; menekannya membuka sheet login.
          IconButton(
            tooltip: 'Pengajuan Saya',
            icon: const Icon(Icons.history),
            onPressed: _openMine,
          ),
          if (_viewer?.isStaff ?? false)
            IconButton(
              tooltip: 'Moderasi Data',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: _openModeration,
            ),
        ],
      ),
      drawer: const LeftDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<CorrectionQueue>(
          future: _queue,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            // Saat memuat ulang, FutureBuilder masih menyimpan data lama: tampilkan dengan
            // garis progres supaya chip dan daftar tidak hilang.
            if (loading && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: 'Gagal memuat antrean.',
                onRetry: _reload,
              );
            }
            return _queueView(snapshot.data!, loading);
          },
        ),
      ),
    );
  }

  Widget _queueView(CorrectionQueue queue, bool loading) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (loading) const LinearProgressIndicator(),
        Text(
          'Bantu lengkapi data produk yang sering muncul di shelf. Nama pengaju tidak ditampilkan.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        QueueStatsGrid(
          stats: queue.stats,
          shelfAvailable: queue.shelfAvailable,
        ),
        const SizedBox(height: 8),
        Text('Urutkan', style: textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in queue.sortOptions)
              ChoiceChip(
                label: Text(option.label),
                selected: option.key == queue.sort,
                onSelected: (_) =>
                    _show(sort: option.key, missing: queue.missing),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Data yang kurang', style: textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Semua'),
              selected: queue.missing == null,
              onSelected: (_) => _show(sort: queue.sort),
            ),
            for (final option in queue.missingOptions)
              ChoiceChip(
                label: Text(option.label),
                selected: option.key == queue.missing,
                onSelected: (_) => _show(sort: queue.sort, missing: option.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${formatThousands(queue.count)} produk',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (queue.results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              queue.missing == null
                  ? 'Semua data produk sudah lengkap.'
                  : 'Tidak ada produk yang kekurangan data jenis ini.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          for (final product in queue.results)
            QueueProductCard(
              product: product,
              onContribute: () => _contribute(product),
            ),
          _pagination(queue),
        ],
      ],
    );
  }

  Widget _pagination(CorrectionQueue queue) {
    final previous = queue.previousPage;
    final next = queue.nextPage;
    return Column(
      children: [
        Text(
          'Halaman ${queue.page} dari ${queue.numPages}',
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: previous == null
                  ? null
                  : () => _show(
                      sort: queue.sort,
                      missing: queue.missing,
                      page: previous,
                    ),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Sebelumnya'),
            ),
            TextButton(
              onPressed: next == null
                  ? null
                  : () => _show(
                      sort: queue.sort,
                      missing: queue.missing,
                      page: next,
                    ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Berikutnya'), Icon(Icons.chevron_right)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
