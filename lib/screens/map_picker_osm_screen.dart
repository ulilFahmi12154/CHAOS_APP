import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MapPickerOsmScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerOsmScreen({super.key, this.initialPosition});

  @override
  State<MapPickerOsmScreen> createState() => _MapPickerOsmScreenState();
}

class _MapPickerOsmScreenState extends State<MapPickerOsmScreen> {
  late MapController _mapController;
  late LatLng _center;
  bool _isLoadingLocation = false;
  String? _address;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? LatLng(-7.797068, 110.370529);
    _mapController = MapController();

    // Auto-detect lokasi saat pertama buka
    if (widget.initialPosition == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController.move(_center, 16.0);
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _onMapMove(MapPosition pos, bool hasGesture) {
    setState(() {
      _center = pos.center!;
    });

    // Debounce: tunggu user berhenti geser peta baru fetch address
    if (hasGesture) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchAddress();
      });
    }
  }

  Future<void> _fetchAddress() async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${_center.latitude}&lon=${_center.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'ChaosSmartFarm/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;

        if (displayName != null && mounted) {
          setState(() {
            // Parse alamat: ambil jalan, kelurahan, kecamatan, kota
            final address = data['address'] as Map<String, dynamic>?;
            if (address != null) {
              final road = address['road'] ?? '';
              final suburb = address['suburb'] ?? address['village'] ?? '';
              final city =
                  address['city'] ?? address['town'] ?? address['county'] ?? '';

              final parts = [
                road,
                suburb,
                city,
              ].where((s) => s.isNotEmpty).toList();
              _address = parts.isEmpty ? displayName : parts.join(', ');
            } else {
              _address = displayName;
            }
          });
        }
      }
    } catch (e) {
      // Gagal fetch address, tidak apa-apa
      if (mounted) {
        setState(() {
          _address = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onPick() {
    Navigator.of(context).pop({
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'address': _address ?? 'Lokasi tidak diketahui',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Lokasi di Peta (OSM)')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _center,
              zoom: 16.0,
              onPositionChanged: _onMapMove,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.chaos.smartfarm',
                maxNativeZoom: 19,
                maxZoom: 19,
              ),
            ],
          ),
          Center(child: Icon(Icons.location_on, size: 48, color: Colors.red)),
          if (_isLoadingLocation)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Mencari lokasi Anda...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address ?? 'Geser peta untuk memilih lokasi',
                            style: TextStyle(
                              fontSize: 13,
                              color: _address != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lat: ${_center.latitude.toStringAsFixed(6)}, Lng: ${_center.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _onPick,
                      child: const Text('Pilih Lokasi Ini'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
