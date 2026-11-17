import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class ShelvesPage extends StatelessWidget {
  const ShelvesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shelf')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Shelf (Daffaa)')),
    );
  }
}
