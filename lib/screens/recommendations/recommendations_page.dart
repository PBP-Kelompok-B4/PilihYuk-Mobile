import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekomendasi')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Rekomendasi (Rafael)')),
    );
  }
}
