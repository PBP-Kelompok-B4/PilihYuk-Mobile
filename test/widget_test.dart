import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilihyuk_mobile/main.dart';

void main() {
  testWidgets('drawer opens every module page', (tester) async {
    await tester.pumpWidget(const PilihYukApp());
    const titles = ['Katalog Produk', 'Shelf', 'Rekomendasi', 'Antrean Data', 'Preferensi'];
    for (final title in titles) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
    }
  });
}
