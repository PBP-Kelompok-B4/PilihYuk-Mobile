import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/config.dart';
import 'package:pilihyuk_mobile/screens/data_correction/data_correction_page.dart';
import 'package:pilihyuk_mobile/screens/login.dart';
import 'package:pilihyuk_mobile/screens/preferences/preferences_page.dart';
import 'package:pilihyuk_mobile/screens/product_catalog/product_catalog_page.dart';
import 'package:pilihyuk_mobile/screens/recommendations/recommendations_page.dart';
import 'package:pilihyuk_mobile/screens/shelves/shelves_page.dart';

class LeftDrawer extends StatelessWidget {
  const LeftDrawer({super.key});

  static final modules = <(String, IconData, Widget Function())>[
    ('Katalog Produk', Icons.inventory_2_outlined, () => const ProductCatalogPage()),
    ('Shelf', Icons.view_column_outlined, () => const ShelvesPage()),
    ('Rekomendasi', Icons.thumb_up_alt_outlined, () => const RecommendationsPage()),
    ('Antrean Data', Icons.fact_check_outlined, () => const DataCorrectionPage()),
    ('Preferensi', Icons.tune, () => const PreferencesPage()),
  ];

  void open(BuildContext context, Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final request = context.watch<CookieRequest>();
    final name = request.loggedIn ? request.jsonData['display_name'] : null;
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('PilihYuk',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(name == null ? 'Bandingkan produk, pilih yang paling cocok.' : 'Halo, $name',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          for (final (title, icon, page) in modules)
            ListTile(leading: Icon(icon), title: Text(title), onTap: () => open(context, page())),
          const Divider(),
          if (request.loggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: () async {
                final response = await request.logout('$baseUrl/api/v1/auth/logout/');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(response['message'] ?? 'Gagal keluar.')));
                open(context, const ProductCatalogPage());
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Masuk'),
              onTap: () => open(context, const LoginPage()),
            ),
        ],
      ),
    );
  }
}
