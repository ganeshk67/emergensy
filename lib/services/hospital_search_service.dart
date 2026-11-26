import 'dart:convert';

import 'package:http/http.dart' as http;

class HospitalPlace {
  const HospitalPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
}

class MapSearchLocation {
  const MapSearchLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class HospitalSearchService {
  HospitalSearchService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  DateTime? _lastGeocodeAt;
  final Map<String, MapSearchLocation> _locationCache = {};
  final Map<String, List<HospitalPlace>> _nearbyCache = {};

  static const _headers = {
    'User-Agent': 'Emergensy/1.0 (com.example.emergensy)',
    'Accept': 'application/json',
  };

  Future<MapSearchLocation> searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Enter a city or area.');
    }
    final cacheKey = trimmed.toLowerCase();
    final cachedLocation = _locationCache[cacheKey];
    if (cachedLocation != null) return cachedLocation;
    final lastRequest = _lastGeocodeAt;
    if (lastRequest != null) {
      final elapsed = DateTime.now().difference(lastRequest);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastGeocodeAt = DateTime.now();

    final response = await _client
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'jsonv2',
            'limit': '1',
            'q': trimmed,
          }),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
        'Map search is unavailable right now (${response.statusCode}). Try again or use your current location.',
      );
    }

    final results = jsonDecode(response.body);
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw Exception(
        'No map location found for "$trimmed". Try a nearby city or area.',
      );
    }
    final result = Map<String, Object?>.from(results.first as Map);
    final latitude = double.tryParse(result['lat']?.toString() ?? '');
    final longitude = double.tryParse(result['lon']?.toString() ?? '');
    if (latitude == null ||
        longitude == null ||
        !_validCoordinates(latitude, longitude)) {
      throw const FormatException(
        'The map search returned invalid coordinates.',
      );
    }

    final location = MapSearchLocation(
      label: result['display_name'] as String? ?? trimmed,
      latitude: latitude,
      longitude: longitude,
    );
    _locationCache[cacheKey] = location;
    return location;
  }

  Future<List<HospitalPlace>> searchNearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 12000,
  }) async {
    if (!_validCoordinates(latitude, longitude)) {
      throw ArgumentError('The map center must be valid latitude/longitude.');
    }
    if (radiusMeters < 1000 || radiusMeters > 50000) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'Search radius must be between 1 km and 50 km.',
      );
    }

    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}:$radiusMeters';
    final cached = _nearbyCache[cacheKey];
    if (cached != null) return List<HospitalPlace>.of(cached);

    final lat = latitude.toStringAsFixed(6);
    final lon = longitude.toStringAsFixed(6);
    final query =
        '''
[out:json][timeout:25];
(
  node["amenity"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
  way["amenity"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
  relation["amenity"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
  node["healthcare"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
  way["healthcare"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
  relation["healthcare"~"hospital|clinic"](around:$radiusMeters,$lat,$lon);
);
out center tags;
''';
    Object? decoded;
    Object? lastError;
    for (final host in const [
      'overpass-api.de',
      'overpass.private.coffee',
    ]) {
      try {
        final candidate = await _client
            .post(
              Uri.https(host, '/api/interpreter'),
              headers: _headers,
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 18));
        if (candidate.statusCode == 200) {
          final payload = jsonDecode(candidate.body);
          if (payload is Map && payload['elements'] is List) {
            decoded = payload;
            break;
          }
          lastError = 'unexpected response';
          continue;
        }
        lastError = 'HTTP ${candidate.statusCode}';
      } catch (error) {
        lastError = error;
      }
    }
    if (decoded == null) {
      throw Exception(
        'Hospital listings are temporarily unavailable from the map services${lastError == null ? '' : ' ($lastError)'}. Try again in a moment.',
      );
    }

    if (decoded is! Map || decoded['elements'] is! List) {
      throw const FormatException(
        'The map service returned an unexpected response.',
      );
    }

    final hospitals = <HospitalPlace>[];
    final seen = <String>{};
    for (final rawElement in decoded['elements'] as List) {
      if (rawElement is! Map) continue;
      final element = Map<String, Object?>.from(rawElement);
      final rawTags = element['tags'];
      if (rawTags is! Map) continue;
      final tags = rawTags.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final category = tags['amenity'] ?? tags['healthcare'] ?? '';
      if (category != 'hospital' && category != 'clinic') continue;

      final rawCenter = element['center'];
      final point = rawCenter is Map
          ? Map<String, Object?>.from(rawCenter)
          : element;
      final hospitalLatitude = double.tryParse(point['lat']?.toString() ?? '');
      final hospitalLongitude = double.tryParse(point['lon']?.toString() ?? '');
      if (hospitalLatitude == null ||
          hospitalLongitude == null ||
          !_validCoordinates(hospitalLatitude, hospitalLongitude)) {
        continue;
      }

      final type = element['type']?.toString() ?? 'place';
      final id = '$type-${element['id'] ?? hospitals.length}';
      if (!seen.add(id)) continue;
      hospitals.add(
        HospitalPlace(
          id: id,
          name: tags['name']?.trim().isNotEmpty == true
              ? tags['name']!.trim()
              : category == 'clinic'
              ? 'Clinic'
              : 'Hospital',
          category: category,
          latitude: hospitalLatitude,
          longitude: hospitalLongitude,
          address: _formatAddress(tags),
        ),
      );
    }
    _nearbyCache[cacheKey] = List<HospitalPlace>.unmodifiable(hospitals);
    return hospitals;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static bool _validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static String _formatAddress(Map<String, String> tags) {
    final street = [
      tags['addr:housenumber'],
      tags['addr:street'] ?? tags['addr:road'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return [
      street,
      tags['addr:suburb'] ?? tags['addr:city_district'],
      tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:village'],
      tags['addr:postcode'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
  }
}
