import 'package:flutter/material.dart';
import 'package:pbp_django_auth/pbp_django_auth.dart';
import 'package:provider/provider.dart';
import 'package:pilihyuk_mobile/screens/product_catalog/product_catalog_page.dart';

void main() {
  runApp(const PilihYukApp());
}

class PilihYukApp extends StatelessWidget {
  const PilihYukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => CookieRequest(),
      child: MaterialApp(
        title: 'PilihYuk',
        debugShowCheckedModeBanner: false,
        // Warna sama dengan --color-brand dan --color-page di situs web.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6F4C)),
          scaffoldBackgroundColor: const Color(0xFFF7F5F0),
        ),
        home: const ProductCatalogPage(),
      ),
    );
  }
}
