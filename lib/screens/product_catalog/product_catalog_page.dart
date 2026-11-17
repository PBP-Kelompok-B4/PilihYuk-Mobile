import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class ProductCatalogPage extends StatelessWidget {
  const ProductCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Produk')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Katalog Produk (Yasmin)')),
    );
  }
}
