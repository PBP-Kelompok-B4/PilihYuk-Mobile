import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';
import 'package:provider/provider.dart';

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialRequest) {
      _initialRequest = false;
      _loadCatalog();
    }
  }

  bool _initialRequest = true;

  Future<void> _loadCatalog() async {
    setState(() => _loading = true);
    try {
      // The response contract is not yet confirmed. Do not interpret a response
      // as products or an empty result until the API contract is available.
      await context.read<CookieRequest>().get('$baseUrl/api/v1/products/');
    } catch (_) {
      // A network failure or a non-JSON response uses the same retry state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF16201A);
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Produk')),
      drawer: const LeftDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          const Text('Katalog Produk',
              style: TextStyle(fontSize: 28, height: 1.18,
                  fontWeight: FontWeight.bold, color: ink)),
          const SizedBox(height: 24),
          const Text('Cari produk',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: ink)),
          const SizedBox(height: 8),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Cari nama produk atau merek...',
              helperText: 'Pencarian belum tersedia.',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCFC9BB)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Filter'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Filter belum tersedia.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6E756E))),
          const SizedBox(height: 24),
          if (_loading) const _CatalogSkeleton() else _CatalogUnavailable(onRetry: _loadCatalog),
        ],
      ),
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat katalog',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Memuat katalog...', style: TextStyle(fontSize: 12, color: Color(0xFF969C95))),
          const SizedBox(height: 12),
          const _SkeletonBar(width: 200, height: 14),
          const SizedBox(height: 12),
          const _SkeletonBar(width: 140, height: 14),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              const Expanded(child: Column(children: [
                _SkeletonBar(height: 70), SizedBox(height: 8),
                _SkeletonBar(height: 11), SizedBox(height: 8), _SkeletonBar(height: 11),
              ])),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9E5DB),
          borderRadius: BorderRadius.circular(height == 70 ? 10 : 7),
        ),
      );
}

class _CatalogUnavailable extends StatelessWidget {
  const _CatalogUnavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Katalog belum tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Produk belum dapat ditampilkan. Coba lagi nanti.'),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ]),
      );
}
