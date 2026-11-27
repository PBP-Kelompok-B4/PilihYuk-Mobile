import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilihyuk_mobile/screens/data_correction/correction_widgets.dart';

/// Satu Scaffold berisi body, lebar 360 dp. textScale untuk memeriksa huruf besar.
Future<void> pumpBody(
  WidgetTester tester,
  Widget body, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: body),
    ),
  );
}

void main() {
  testWidgets(
    'ErrorView inside another list is a card whose Coba lagi retries',
    (tester) async {
      var retries = 0;
      await pumpBody(
        tester,
        Column(
          children: [
            ErrorView(
              message: 'Gagal memuat panduan.',
              onRetry: () => retries++,
              scrollable: false,
            ),
          ],
        ),
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Gagal memuat panduan.'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      expect(retries, 1);
    },
  );

  testWidgets(
    'EmptyState shows a full-width 48 dp button only with an action',
    (tester) async {
      var taps = 0;
      await pumpBody(
        tester,
        ListView(
          children: [
            const EmptyState(icon: Icons.inbox_outlined, title: 'Kosong.'),
            EmptyState(
              icon: Icons.search,
              title: 'Tidak ada produk yang cocok.',
              actionLabel: 'Bersihkan filter',
              onAction: () => taps++,
            ),
          ],
        ),
      );
      // Satu tombol selebar isi kartu: 360 dikurangi padding 18 dan garis kartu 1 di kiri dan kanan.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), const Size(322, 48));

      await tester.tap(find.text('Bersihkan filter'));
      expect(taps, 1);
    },
  );

  testWidgets('showToast floats a dark toast; a failure gets the info icon', (
    tester,
  ) async {
    await pumpBody(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => showToast(context, withdrawnMessage),
              child: const Text('sukses'),
            ),
            TextButton(
              onPressed: () => showToast(
                context,
                'Server sedang bermasalah. Coba lagi nanti.',
                success: false,
                action: SnackBarAction(label: 'Coba lagi', onPressed: () {}),
              ),
              child: const Text('galat'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('sukses'));
    await tester.pumpAndSettle();
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, CorrectionColors.ink);
    expect(find.text(withdrawnMessage), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.tap(find.text('galat'));
    await tester.pumpAndSettle();
    expect(find.text(withdrawnMessage), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Coba lagi'), findsOneWidget);
  });

  testWidgets(
    'PageNav disables a missing page and fits 360 dp at double text size',
    (tester) async {
      var next = 0;
      await pumpBody(
        tester,
        Padding(
          padding: const EdgeInsets.all(CorrectionSizes.inset),
          child: PageNav(
            page: 1,
            numPages: 18,
            onPrevious: null,
            onNext: () => next++,
          ),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Halaman 1 dari 18'), findsOneWidget);
      final previous = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Sebelumnya'),
          matching: find.byType(TextButton),
        ),
      );
      expect(previous.onPressed, isNull);

      await tester.tap(find.text('Berikutnya'));
      expect(next, 1);
    },
  );
}
