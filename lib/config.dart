// Ganti saat run lokal: flutter run --dart-define=BASE_URL=http://10.0.2.2:8000
const baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://ahmad-rizki53-pilihyuk.pws.cs.ui.ac.id',
);
