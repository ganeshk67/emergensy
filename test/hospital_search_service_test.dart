import 'dart:convert';

import 'package:emergensy/services/hospital_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'searchNearby parses and validates OpenStreetMap hospital results',
    () async {
      late http.Request request;
      final client = MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 12,
                'lat': 18.52,
                'lon': 73.85,
                'tags': {
                  'amenity': 'hospital',
                  'name': 'City Hospital',
                  'addr:street': 'Main Road',
                  'addr:city': 'Pune',
                },
              },
              {
                'type': 'way',
                'id': 34,
                'center': {'lat': 18.53, 'lon': 73.86},
                'tags': {'healthcare': 'clinic', 'name': 'Community Clinic'},
              },
              {
                'type': 'node',
                'id': 56,
                'lat': 140,
                'lon': 73.8,
                'tags': {'amenity': 'hospital', 'name': 'Invalid location'},
              },
            ],
          }),
          200,
        );
      });
      final service = HospitalSearchService(client: client);

      final hospitals = await service.searchNearby(
        latitude: 18.5,
        longitude: 73.8,
      );

      expect(request.url.host, 'overpass-api.de');
      final query = Uri.splitQueryString(request.body)['data'];
      expect(query, contains('around:12000,18.500000,73.800000'));
      expect(hospitals, hasLength(2));
      expect(hospitals.first.name, 'City Hospital');
      expect(hospitals.first.address, 'Main Road, Pune');
      expect(hospitals.last.category, 'clinic');
      expect(hospitals.last.latitude, 18.53);
      client.close();
    },
  );

  test('searchLocation resolves a city from OpenStreetMap', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode([
          {
            'display_name': 'Pune, Maharashtra, India',
            'lat': '18.5204',
            'lon': '73.8567',
          },
        ]),
        200,
      );
    });
    final service = HospitalSearchService(client: client);

    final location = await service.searchLocation('Pune');

    expect(request.url.host, 'nominatim.openstreetmap.org');
    expect(request.url.queryParameters['q'], 'Pune');
    expect(location.label, 'Pune, Maharashtra, India');
    expect(location.latitude, 18.5204);
    client.close();
  });
}
