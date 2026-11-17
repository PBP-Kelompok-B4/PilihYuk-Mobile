import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class DataCorrectionPage extends StatelessWidget {
  const DataCorrectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Data')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Antrean Data (Rayyan)')),
    );
  }
}
