import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LiveMap extends StatefulWidget {
  const LiveMap({super.key});

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  late final MapController _mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _statusText = "Checking flood status...";
  Color _statusColor = Colors.grey;
  List<CircleMarker> _riskCircles = [];

  final String _apiKey = "c0c37a7969052eb7cc9e7fe020a96981"; // Replace with your API key

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!mounted) return;

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    await _checkFloodStatus();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 15.0);
      }
    });
  }

  Future<void> _checkFloodStatus() async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/3.0/onecall?lat=${_currentPosition!.latitude}&lon=${_currentPosition!.longitude}&exclude=minutely,hourly&appid=$_apiKey&units=metric",
    );

    try {
      final response = await http.get(url);
      print('API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API response data: $data');

        if (!mounted) return;

        setState(() {
          if (data["alerts"] != null && data["alerts"].isNotEmpty) {
            final alert = data["alerts"][0]["event"].toString().toLowerCase();
            print('Flood alert found: $alert');

            if (alert.contains("flood warning")) {
              _statusText = "High Risk: Flood Warning";
              _statusColor = Colors.blue[900]!;
              _riskCircles = [
                CircleMarker(point: _currentPosition!, color: Colors.blue[900]!.withOpacity(0.4), radius: 80000),
              ];
            } else if (alert.contains("flood watch") || alert.contains("advisory")) {
              _statusText = "Moderate Risk: Flood Watch";
              _statusColor = Colors.blue[500]!;
              _riskCircles = [
                CircleMarker(point: _currentPosition!, color: Colors.blue[500]!.withOpacity(0.4), radius: 80000),
              ];
            } else {
              _setSafeZone();
              print('No flood warning or watch in alerts, set safe zone');
            }
          } else {
            _setSafeZone();
            print('No alerts in data, set safe zone');
          }
        });
      } else {
        print('API response status not 200, set safe zone');
        if (!mounted) return;
        setState(() {
          _setSafeZone();
        });
      }
    } catch (e) {
      print('Exception during API call: $e');
      if (!mounted) return;
      setState(() {
        _setSafeZone();
      });
    }
  }

  void _setSafeZone() {
    _statusText = "Safe Zone";
    _statusColor = Colors.green[700]!;
    _riskCircles = [
      CircleMarker(point: _currentPosition!, color: Colors.green.withOpacity(0.4), radius: 80000),
    ];
  }

  @override
  Widget build(BuildContext context) {
    print('Risk circles count: ${_riskCircles.length}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 10.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.floodsense2',
                    ),
                    CircleLayer(circles: _riskCircles),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Legend
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white.withOpacity(0.8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem(Colors.blue[900]!, "High Risk (Dark Blue)"),
                        _legendItem(Colors.blue[500]!, "Moderate Risk (Blue)"),
                        _legendItem(Colors.green, "Safe (Green)"),
                      ],
                    ),
                  ),
                ),

                // Status Section
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Status: $_statusText",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
