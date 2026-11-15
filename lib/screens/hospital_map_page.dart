import 'package:emergensy/services/hospital_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalMapPage extends StatefulWidget {
  const HospitalMapPage({this.service, super.key});

  final HospitalSearchService? service;

  @override
  State<HospitalMapPage> createState() => _HospitalMapPageState();
}

class _HospitalMapPageState extends State<HospitalMapPage> {
  static const _defaultCenter = LatLng(20.5937, 78.9629);
  static const _searchRadiusMeters = 12000;

  late final HospitalSearchService _service =
      widget.service ?? HospitalSearchService();
  final _mapController = MapController();
  final _areaController = TextEditingController();
  final _distance = const Distance();
  LatLng? _center;
  String? _locationLabel;
  List<HospitalPlace> _hospitals = [];
  HospitalPlace? _selectedHospital;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _areaController.dispose();
    _mapController.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _findNearMe() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedHospital = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Turn on device location services, or search for a city or area.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Search for a city or area instead.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is disabled in settings. Search for a city or area instead.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _loadHospitals(
        LatLng(position.latitude, position.longitude),
        label: 'Near your current location',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _searchArea() async {
    if (_loading) return;
    final query = _areaController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a city or area to search.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _selectedHospital = null;
    });
    try {
      final location = await _service.searchLocation(query);
      await _loadHospitals(
        LatLng(location.latitude, location.longitude),
        label: location.label,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadHospitals(LatLng center, {required String label}) async {
    try {
      final hospitals = await _service.searchNearby(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: _searchRadiusMeters,
      );
      if (!mounted) return;
      hospitals.sort(
        (a, b) => _distanceTo(center, a).compareTo(_distanceTo(center, b)),
      );
      setState(() {
        _center = center;
        _locationLabel = label;
        _hospitals = hospitals;
        _selectedHospital = null;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(center, 13);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double _distanceTo(LatLng center, HospitalPlace hospital) => _distance.as(
    LengthUnit.Kilometer,
    center,
    LatLng(hospital.latitude, hospital.longitude),
  );

  void _selectHospital(HospitalPlace hospital) {
    setState(() => _selectedHospital = hospital);
  }

  void _useSelectedHospital() {
    final hospital = _selectedHospital;
    if (hospital != null) Navigator.of(context).pop(hospital);
  }

  Future<void> _openDirections(HospitalPlace hospital) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${hospital.latitude},${hospital.longitude}',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No maps app could open this destination.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open directions: $error')),
      );
    }
  }

  List<Marker> _markers(ColorScheme colors) {
    final center = _center;
    return [
      if (center != null)
        Marker(
          point: center,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Color(0xFF1976D2),
            size: 28,
          ),
        ),
      for (final hospital in _hospitals)
        Marker(
          point: LatLng(hospital.latitude, hospital.longitude),
          width: 44,
          height: 48,
          child: IconButton(
            tooltip: hospital.name,
            onPressed: () => _selectHospital(hospital),
            icon: Icon(
              hospital.category == 'clinic'
                  ? Icons.medical_services
                  : Icons.local_hospital,
              color: _selectedHospital?.id == hospital.id
                  ? colors.tertiary
                  : colors.primary,
              size: 32,
            ),
          ),
        ),
    ];
  }

  Widget _searchResults(ColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, color: colors.error),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _areaController.text.trim().isEmpty
                    ? _findNearMe
                    : _searchArea,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_center == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Use your location or search a city or area to see nearby hospitals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hospitals or clinics were listed within 12 km of this area. Try another location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final hospital = _hospitals[index];
        final selected = hospital.id == _selectedHospital?.id;
        final distance = _distanceTo(_center!, hospital);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _selectHospital(hospital),
                  leading: Icon(
                    hospital.category == 'clinic'
                        ? Icons.medical_services_outlined
                        : Icons.local_hospital_outlined,
                    color: selected ? colors.tertiary : colors.primary,
                  ),
                  title: Text(
                    hospital.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      '${distance.toStringAsFixed(1)} km · ${hospital.category}',
                      if (hospital.address.isNotEmpty) hospital.address,
                    ].join('\n'),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openDirections(hospital),
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Directions'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => _selectHospital(hospital),
                      child: Text(selected ? 'Selected' : 'Select'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby hospitals')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _areaController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchArea(),
                    decoration: InputDecoration(
                      labelText: 'Search by city or area',
                      hintText: 'For example, Pune',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Search area',
                        onPressed: _loading ? null : _searchArea,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _findNearMe,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use my current location'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 4,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.emergensy',
                  ),
                  MarkerLayer(markers: _markers(colors)),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.https('www.openstreetmap.org', '/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _locationLabel ?? 'Map of India',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Within 12 km',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Searches use OpenStreetMap services. Listings may be incomplete; directions open an external maps app.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
              ),
            ),
            Expanded(flex: 4, child: _searchResults(colors)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton.icon(
            onPressed: _selectedHospital == null ? null : _useSelectedHospital,
            icon: const Icon(Icons.check),
            label: Text(
              _selectedHospital == null
                  ? 'Select a hospital to continue'
                  : 'Use ${_selectedHospital!.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
