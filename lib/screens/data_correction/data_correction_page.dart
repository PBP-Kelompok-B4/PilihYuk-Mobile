import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/data_correction.dart';
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
  late Future<CorrectionQueue> _queue = _fetch();

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

  // Chip dan tombol halaman memakai sort dan missing dari balasan terakhir.
  void _show({required String sort, String? missing, int page = 1}) {
    _sort = sort;
    _missing = missing;
    _page = page;
    _reload();
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Segera hadir')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Data')),
      drawer: const LeftDrawer(),
      body: RefreshIndicator(
        onRefresh: _reload,
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
              return _message(
                'Gagal memuat antrean. Tarik ke bawah untuk mencoba lagi.',
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
            QueueProductCard(product: product, onContribute: _comingSoon),
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

  // ListView, supaya tarik-untuk-muat-ulang tetap bisa saat galat.
  Widget _message(String text) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    ],
  );
}
