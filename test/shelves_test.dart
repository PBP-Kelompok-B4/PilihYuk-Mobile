import 'package:flutter_test/flutter_test.dart';
import 'package:pilihyuk_mobile/models/shelves.dart';

void main() {
  test('Shelf.fromJson reads the shelf list API fields', () {
    final shelf = Shelf.fromJson({
      'id': 3,
      'name': 'Mie instan',
      'store_context': 'Alfamart',
      'description': '',
      'is_private': false,
      'owner': 'Rani',
      'item_count': 4,
      'save_count': 1,
      'updated_at': '2026-11-20T10:00:00Z',
    });
    expect([shelf.id, shelf.name, shelf.storeContext, shelf.owner, shelf.itemCount, shelf.saveCount],
        [3, 'Mie instan', 'Alfamart', 'Rani', 4, 1]);
  });
}
