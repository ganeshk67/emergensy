import 'package:emergensy/services/hospital_search_service.dart';
import 'package:emergensy/widgets/emergency_motion.dart';
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

class _HospitalMapPageState extends State<HospitalMapPage>
    with SingleTickerProviderStateMixin {
  static const _defaultCenter = LatLng(20.5937, 78.9629);
  static const _searchRadiusMeters = 12000;

  late final HospitalSearchService _service =
      widget.service ?? HospitalSearchService();
  final _mapController = MapController();
  final _areaController = TextEditingController();
  final _distance = const Distance();
  late final AnimationController _cameraAnimation;
  LatLng? _cameraStart;
  LatLng? _cameraTarget;
  double _zoomStart = 4;
  double _zoomTarget = 4;
  double? _accuracyMeters;
  bool _mapReady = false;
  LatLng? _center;
  String? _locationLabel;
  List<HospitalPlace> _hospitals = [];
  HospitalPlace? _selectedHospital;
  bool _loading = false;
  String? _error;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _cameraAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..addListener(_updateCamera);
  }

  void _updateCamera() {
    final from = _cameraStart;
    final to = _cameraTarget;
    if (!_mapReady || from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_cameraAnimation.value);
    _mapController.move(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      _zoomStart + (_zoomTarget - _zoomStart) * t,
    );
  }

  void _animateCamera(LatLng target, double zoom) {
    if (!_mapReady) return;
    _cameraAnimation.stop();
    _cameraStart = _mapController.camera.center;
    _cameraTarget = target;
    _zoomStart = _mapController.camera.zoom;
    _zoomTarget = zoom;
    if (MediaQuery.of(context).disableAnimations) {
      _mapController.move(target, zoom);
    } else {
      _cameraAnimation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _cameraAnimation.dispose();
    _areaController.dispose();
    _mapController.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _findNearMe() async {
    final generation = ++_searchGeneration;
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

      // A cached fix makes the map useful immediately when the OS already
      // knows the device location; otherwise ask for a fresh balanced fix.
      final cached = await Geolocator.getLastKnownPosition();
      final position =
          cached ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
      if (!mounted || generation != _searchGeneration) return;
      await _loadHospitals(
        LatLng(position.latitude, position.longitude),
        label: 'Near your current location',
        accuracyMeters: position.accuracy,
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
    final generation = ++_searchGeneration;
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
      if (!mounted || generation != _searchGeneration) return;
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

  Future<void> _loadHospitals(
    LatLng center, {
    required String label,
    double? accuracyMeters,
  }) async {
    final generation = _searchGeneration;
    try {
      final hospitals = await _service.searchNearby(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: _searchRadiusMeters,
      );
      if (!mounted || generation != _searchGeneration) return;
      hospitals.sort(
        (a, b) => _distanceTo(center, a).compareTo(_distanceTo(center, b)),
      );
      setState(() {
        _center = center;
        _accuracyMeters = accuracyMeters;
        _locationLabel = label;
        _hospitals = hospitals;
        _selectedHospital = null;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateCamera(center, 13);
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
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
    setState(() {
      _selectedHospital = hospital;
      _accuracyMeters = null;
    });
    _animateCamera(LatLng(hospital.latitude, hospital.longitude), 15);
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
          width: 48,
          height: 48,
          child: const AnimatedLocationMarker(),
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

  Widget _searchResults(ColorScheme colors, ScrollController scrollController) {
    if (_loading) {
      return SingleChildScrollView(
        controller: scrollController,
        child: const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return SingleChildScrollView(
        controller: scrollController,
        child: Center(
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
        ),
      );
    }
    if (_center == null) {
      return SingleChildScrollView(
        controller: scrollController,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Use your location or search a city or area to see nearby hospitals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    if (_hospitals.isEmpty) {
      return SingleChildScrollView(
        controller: scrollController,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No hospitals or clinics were listed within 12 km of this area. Try another location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby hospitals')),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 4,
                  onMapReady: () => _mapReady = true,
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
                  if (_center != null && _accuracyMeters != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center!,
                          radius: _accuracyMeters!,
                          useRadiusInMeter: true,
                          color: const Color(0x33168BE5),
                          borderColor: const Color(0x99168BE5),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
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
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: .2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loading ? null : _findNearMe,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Use my current location'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: .36,
              minChildSize: .24,
              maxChildSize: .72,
              snap: !reduceMotion,
              snapSizes: const [.36, .72],
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .98),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: colors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                      child: Column(
                        children: [
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: .4,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _center == null
                                          ? 'Nearby care'
                                          : 'Hospitals & clinics',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _locationLabel ?? 'Map of India',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Within 12 km',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _searchResults(colors, scrollController)),
                    if (_selectedHospital != null)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _useSelectedHospital,
                              icon: const Icon(Icons.check),
                              label: Text(
                                'Use ${_selectedHospital!.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'OpenStreetMap listings may be incomplete. Directions open your maps app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
