// Regression test for the missing region_id (Styleya backend API doc, 2026-10-13).
//
// Styleya resolves shipping rates by Magento region, and the address only ever
// carried the governorate's name: Address.toMagentoJson had `region_id`
// commented out. The id now travels with the name — picked from /V1/city in
// the address form, kept in local storage, read from Magento — and is sent
// whenever it is known. An unknown id is left out rather than sent as 0.
//
// Payloads are built with jsonDecode, as in address_default_flags_test.dart,
// because the app feeds these constructors jsonDecode output.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/models/entities/address.dart';

Address _cairo({String? regionId}) => Address(
      firstName: 'Mona',
      lastName: 'Ali',
      street: '1 Nile St',
      city: 'Nasr City',
      state: 'Cairo',
      country: 'EG',
      phoneNumber: '01012345678',
    )..regionId = regionId;

void main() {
  group('Address region_id', () {
    test('is sent as an integer when known', () {
      final json = _cairo(regionId: '1102').toMagentoJson()['address'];

      expect(json['region_id'], 1102);
      expect(json['region'], 'Cairo');
    });

    test('is left out when unknown, not sent as 0', () {
      final json = _cairo().toMagentoJson()['address'] as Map;

      expect(json.containsKey('region_id'), isFalse);
      expect(json['region'], 'Cairo');
    });

    test('survives local storage', () {
      final stored = jsonDecode(jsonEncode(_cairo(regionId: '1102').toJson()));
      final encodable =
          jsonDecode(jsonEncode(_cairo(regionId: '1102').toJsonEncodable()));

      expect(Address.fromLocalJson(stored).regionId, '1102');
      expect(Address.fromLocalJson(encodable).regionId, '1102');
    });

    test('is dropped when a legacy address has its governorate moved over', () {
      // Old saved addresses kept the governorate in `city`; fromLocalJson
      // shifts it into `state`. Any id stored alongside belonged to nothing.
      final legacy = jsonDecode(
          '{"city": "Cairo", "address_2": "Nasr City", "state": "",'
          ' "region_id": "999"}');

      final address = Address.fromLocalJson(legacy);

      expect(address.state, 'Cairo');
      expect(address.regionId, isNull);
    });

    test('is read from a Magento order address', () {
      final json = jsonDecode(
          '{"firstname": "Mona", "region": "Cairo", "region_id": 1102,'
          ' "country_id": "EG", "city": "Nasr City"}');

      expect(Address.fromMagentoJson(json).regionId, '1102');
    });
  });
}
