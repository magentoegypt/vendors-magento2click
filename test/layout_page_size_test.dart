// Regression test for unbounded home-layout product requests (Styleya backend
// API doc, 2026-10-13: "Always send pageSize: without it every matching
// product is returned").
//
// fetchProductsLayout only sent searchCriteria[pageSize] together with a
// category filter, so a layout block without a category fetched the whole
// catalogue. A blank or 0 `limit` in the layout JSON did the same. Every
// request now carries MagentoService.layoutPageSize(config).

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/common/constants.dart';
import 'package:magentoegypt/frameworks/magento/services/magento_service.dart';
import 'package:magentoegypt/services/service_config.dart';

void main() {
  group('MagentoService.layoutPageSize', () {
    // apiPageSize reads the server type.
    setUpAll(() => ServerConfig().setConfig({'type': 'magento'}));

    test('uses the layout\'s limit when it is a positive number', () {
      expect(MagentoService.layoutPageSize({'limit': 8}), 8);
      expect(MagentoService.layoutPageSize({'limit': '12'}), 12);
      expect(MagentoService.layoutPageSize({'limit': 6.0}), 6);
    });

    test('falls back to a carousel\'s worth for an unpaged block', () {
      for (final limit in [null, '', 0, '0', -3, 'abc']) {
        expect(
          MagentoService.layoutPageSize({'category': '21', 'limit': limit}),
          kHomeCarouselLimit,
          reason: 'limit: ${limit.runtimeType} $limit',
        );
      }
      // The case that used to fetch everything: no category, no limit.
      expect(MagentoService.layoutPageSize({'layout': 'saleOff'}),
          kHomeCarouselLimit);
    });

    test('falls back to a full page for a paged layout', () {
      expect(MagentoService.layoutPageSize({'page': 2}), apiPageSize);
      expect(MagentoService.layoutPageSize({'page': 1, 'limit': ''}),
          apiPageSize);
    });
  });
}
