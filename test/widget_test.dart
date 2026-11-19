import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilihyuk_mobile/main.dart';

void main() {
  testWidgets('drawer opens every module page', (tester) async {
    await tester.pumpWidget(const PilihYukApp());
    // Not pumpAndSettle: a loading spinner on a page that fetches data never settles.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    const titles = ['Katalog Produk', 'Shelf', 'Rekomendasi', 'Antrean Data', 'Preferensi'];
    for (final title in titles) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await settle();
      await tester.tap(find.widgetWithText(ListTile, title));
      await settle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
    }
  });
}
