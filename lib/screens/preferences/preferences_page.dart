import 'package:flutter/material.dart';
import 'package:pilihyuk_mobile/widgets/left_drawer.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferensi')),
      drawer: const LeftDrawer(),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrien yang dibandingkan'),
            SizedBox(height: 50),
            Text('Protein'),
            SizedBox(height: 10),
            Text('Serat'),
            SizedBox(height: 10),
            Text('Gula'),
            SizedBox(height: 10),
            Text('Natrium'),
            SizedBox(height: 10),
            Text('Lemak Jenuh'),
            SizedBox(height: 10),
            Text('Kalori'),
          ],
        ),
      ),
    );
  }
}
