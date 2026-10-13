// Regression test for home layout blocks ignoring their sort.
//
// A block's sort is stored under `orderby` (ProductConfig), but
// fetchProductsLayout checked `orderby` and then read `orderBy`, so the field
// was always getOrderByKey(null) = created_at. Field and direction were also
// sent independently: `order` alone named no field, and `orderby` alone sorted
// ascending. MagentoService.layoutSortQuery now sends both together, and
// nothing for a block that sets neither.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_service.dart';

String _sort(String field, String direction) =>
    '&searchCriteria[sortOrders][1][field]=$field'
    '&searchCriteria[sortOrders][1][direction]=$direction';

void main() {
  final service = MagentoService(domain: 'https://example.test', accessToken: '');

  group('MagentoService.layoutSortQuery', () {
    test('uses the block\'s orderby, not created_at', () {
      expect(service.layoutSortQuery({'orderby': 'price', 'order': 'asc'}),
          _sort('price', 'ASC'));
      expect(service.layoutSortQuery({'orderby': 'title', 'order': 'desc'}),
          _sort('name', 'DESC'));
      expect(service.layoutSortQuery({'orderby': 'menu_order', 'order': 'asc'}),
          _sort('position', 'ASC'));
    });

    test('defaults the direction to newest first when only orderby is set', () {
      expect(service.layoutSortQuery({'orderby': 'date'}),
          _sort('created_at', 'DESC'));
    });

    test('names a field when only order is set', () {
      expect(service.layoutSortQuery({'order': 'asc'}),
          _sort('created_at', 'ASC'));
    });

    test('leaves the endpoint\'s own order when neither is set', () {
      expect(service.layoutSortQuery({'category': '21'}), '');
      expect(service.layoutSortQuery({'orderby': null, 'order': null}), '');
    });
  });
}
