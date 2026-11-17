import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferensi')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Preferensi (Jonathan)')),
    );
  }
}
