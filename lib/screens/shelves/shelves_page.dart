import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/models/shelves.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class ShelvesPage extends StatefulWidget {
  const ShelvesPage({super.key});

  @override
  State<ShelvesPage> createState() => _ShelvesPageState();
}

class _ShelvesPageState extends State<ShelvesPage> {
  String _query = '';
  late Future<List<Shelf>> _shelves = _fetch();

  // shortcut: only the first page (12 shelves) is loaded, add paging with the full list feature.
  Future<List<Shelf>> _fetch() async {
    final request = context.read<CookieRequest>();
    final data = await request.get('$baseUrl/api/v1/shelves/?q=${Uri.encodeQueryComponent(_query)}');
    return [for (final item in data['results']) Shelf.fromJson(item)];
  }

  Future<void> _reload() {
    setState(() => _shelves = _fetch());
    return _shelves;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shelf')),
      drawer: const LeftDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Cari shelf',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                _query = value.trim();
                _reload();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<Shelf>>(
                future: _shelves,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _message('Gagal memuat shelf. Tarik ke bawah untuk mencoba lagi.');
                  }
                  final shelves = snapshot.data!;
                  if (shelves.isEmpty) {
                    return _message(_query.isEmpty ? 'Belum ada shelf publik.' : 'Shelf tidak ditemukan.');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: shelves.length,
                    itemBuilder: (_, i) => _ShelfCard(shelf: shelves[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A ListView, so pull to refresh also works on an empty or failed list.
  Widget _message(String text) => ListView(
        children: [Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center))],
      );
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.shelf});

  final Shelf shelf;

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
            Text(shelf.name, style: textTheme.titleMedium),
            if (shelf.storeContext.isNotEmpty) Text(shelf.storeContext, style: textTheme.bodySmall),
            if (shelf.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(shelf.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 8),
            Text('${shelf.itemCount} produk · ${shelf.saveCount} disimpan · oleh ${shelf.owner}',
                style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
