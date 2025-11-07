// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

enum FloodRiskLevel { safe, moderate, high }

class AlternateRoutesPage extends StatefulWidget {
  const AlternateRoutesPage({super.key});

  @override
  State<AlternateRoutesPage> createState() => _AlternateRoutesPageState();
}

class _AlternateRoutesPageState extends State<AlternateRoutesPage> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapEventSub;
  bool _mapReady = false;

  static final String ORS_API_KEY = dotenv.env['ORS_API_KEY']!;
  static final String OPENWEATHER_API_KEY = dotenv.env['OPENWEATHER_API_KEY']!;

  bool _loading = false;
  List<RouteOption> _allRoutes = [];
  List<RouteOption> _displayRoutes = [];
  String _statusMessage = "";
  bool _showHighRiskRoutes = false;

  final Map<String, _CachedFlood> _owmCache = {};
  static const int _OWM_MAX_CALLS_PER_MINUTE = 50;
  int _owmCallsThisWindow = 0;
  DateTime _owmWindowStart = DateTime.now();
  static const int _OWM_CACHE_TTL_MIN = 30;

  final Map<String, List<NominatimPlace>> _placeCache = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Mark map as ready once we see the first map event (robust across flutter_map versions)
    _mapEventSub = _mapController.mapEventStream.listen((event) {
      if (!_mapReady) {
        setState(() {
          _mapReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<NominatimPlace>> _searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    if (_placeCache.containsKey(q)) return _placeCache[q]!;

    final completer = Completer<List<NominatimPlace>>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(q)}&format=json&addressdetails=1&limit=6",
      );
      try {
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'com.example.floodapp'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          final places = data
              .map(
                (e) => NominatimPlace(
                  displayName: e['display_name'] ?? "",
                  lat: double.parse(e['lat']),
                  lon: double.parse(e['lon']),
                ),
              )
              .toList();
          _placeCache[q] = places;
          completer.complete(places);
          return;
        }
      } catch (e) {
        debugPrint("Nominatim error: $e");
      }
      completer.complete([]);
    });
    return completer.future;
  }

  Future<LatLng?> _geocode(String address) async {
    final list = await _searchPlaces(address);
    if (list.isNotEmpty) return LatLng(list.first.lat, list.first.lon);
    return null;
  }

  Future<List<RouteOption>> _fetchRoutes(
    LatLng from,
    LatLng to, {
    int alternatives = 3,
  }) async {
    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/driving-car?api_key=$ORS_API_KEY"
      "&start=${from.longitude},${from.latitude}"
      "&end=${to.longitude},${to.latitude}&alternatives=true",
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("ORS routing failed: ${res.statusCode}");
    }

    final data = jsonDecode(res.body);
    final features = (data['features'] as List);
    final results = <RouteOption>[];

    for (var f in features) {
      final coords = (f['geometry']['coordinates'] as List)
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      final summary = f['properties']['summary'];
      final dist = (summary['distance'] as num).toDouble();
      final dur = ((summary['duration'] as num).toDouble() / 60).round();
      results.add(
        RouteOption(
          id: UniqueKey().toString(),
          name: "Route",
          distanceMeters: dist,
          durationMinutes: dur,
          points: coords,
          risk: FloodRiskLevel.safe,
        ),
      );
      if (results.length >= alternatives) break;
    }
    return results;
  }

  Future<FloodRiskLevel> _assessRouteFloodRisk(
    RouteOption route, {
    double sampleMeters = 1000,
  }) async {
    final sampled = _sampleRouteByDistance(route.points, sampleMeters);
    bool sawModerate = false;
    for (var p in sampled) {
      final level = await _checkFloodAtPointWithCache(p);
      if (level == FloodRiskLevel.high) return FloodRiskLevel.high;
      if (level == FloodRiskLevel.moderate) sawModerate = true;
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return sawModerate ? FloodRiskLevel.moderate : FloodRiskLevel.safe;
  }

  Future<FloodRiskLevel> _checkFloodAtPointWithCache(LatLng p) async {
    final key =
        "${p.latitude.toStringAsFixed(3)},${p.longitude.toStringAsFixed(3)}";
    final now = DateTime.now();
    if (_owmCache.containsKey(key)) {
      final entry = _owmCache[key]!;
      if (entry.expires.isAfter(now)) {
        return entry.level;
      } else {
        _owmCache.remove(key);
      }
    }

    if (now.difference(_owmWindowStart).inSeconds >= 60) {
      _owmWindowStart = now;
      _owmCallsThisWindow = 0;
    }

    if (_owmCallsThisWindow >= _OWM_MAX_CALLS_PER_MINUTE) {
      _owmCache[key] = _CachedFlood(
        level: FloodRiskLevel.safe,
        expires: now.add(const Duration(minutes: 5)),
      );
      setState(() => _statusMessage = "Rate limit hit; using cached/fallback.");
      return FloodRiskLevel.safe;
    }

    _owmCallsThisWindow++;
    final url = Uri.parse(
      "https://api.openweathermap.org/data/3.0/onecall?lat=${p.latitude}&lon=${p.longitude}&exclude=minutely,hourly&appid=$OPENWEATHER_API_KEY&units=metric",
    );

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        FloodRiskLevel level = FloodRiskLevel.safe;
        final alerts = data["alerts"];
        if (alerts != null && (alerts as List).isNotEmpty) {
          final ev = alerts[0]["event"].toString().toLowerCase();
          if (ev.contains("flood warning")) {
            level = FloodRiskLevel.high;
          } else if (ev.contains("flood watch") || ev.contains("advisory")) {
            level = FloodRiskLevel.moderate;
          }
        }
        _owmCache[key] = _CachedFlood(
          level: level,
          expires: now.add(const Duration(minutes: _OWM_CACHE_TTL_MIN)),
        );
        return level;
      }
    } catch (e) {
      debugPrint("OpenWeather error: $e");
    }
    _owmCache[key] = _CachedFlood(
      level: FloodRiskLevel.safe,
      expires: now.add(const Duration(minutes: 5)),
    );
    return FloodRiskLevel.safe;
  }

  List<LatLng> _sampleRouteByDistance(List<LatLng> pts, double intervalMeters) {
    if (pts.isEmpty) return [];
    final dist = const Distance();
    final sampled = <LatLng>[pts.first];
    double acc = 0;
    for (int i = 1; i < pts.length; i++) {
      acc += dist(pts[i - 1], pts[i]);
      if (acc >= intervalMeters) {
        sampled.add(pts[i]);
        acc = 0;
      }
    }
    if (sampled.last != pts.last) sampled.add(pts.last);
    return sampled;
  }

  Future<void> _onCheckRoutesPressed() async {
    final fromText = _fromCtrl.text.trim();
    final toText = _toCtrl.text.trim();
    if (fromText.isEmpty || toText.isEmpty) {
      _showSnack("Enter both From and To");
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = "Geocoding...";
      _allRoutes = [];
      _displayRoutes = [];
    });

    final from = await _geocode(fromText);
    final to = await _geocode(toText);
    if (from == null || to == null) {
      setState(() => _loading = false);
      _showSnack("Couldn't geocode one of the addresses");
      return;
    }

    setState(() => _statusMessage = "Fetching routes...");
    List<RouteOption> fetched = [];
    try {
      fetched = await _fetchRoutes(from, to, alternatives: 3);
    } catch (e) {
      debugPrint("Route fetch error: $e");
      setState(() => _loading = false);
      _showSnack("Error fetching routes");
      return;
    }

    setState(() => _statusMessage = "Assessing flood risk...");
    for (var r in fetched) {
      r.risk = await _assessRouteFloodRisk(r);
    }

    _allRoutes = fetched;
    _updateDisplayRoutes();

    if (fetched.isNotEmpty && fetched.first.points.isNotEmpty) {
      // preferred: move only if map is ready
      if (_mapReady) {
        _mapController.move(fetched.first.points.first, 12);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(fetched.first.points.first, 12);
          } catch (_) {}
        });
      }
    }

    setState(() {
      _loading = false;
      _statusMessage = _displayRoutes.isEmpty
          ? "No safe routes available."
          : "${_displayRoutes.length} route(s) available";
    });
  }

  void _updateDisplayRoutes() {
    _displayRoutes = _showHighRiskRoutes
        ? List<RouteOption>.from(_allRoutes)
        : _allRoutes.where((r) => r.risk != FloodRiskLevel.high).toList();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmToggleHighRisk(bool val) async {
    if (val) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Show HIGH-RISK routes?"),
          content: const Text(
            "These routes may be unsafe due to flood warnings. Show anyway?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _showHighRiskRoutes = val;
      _updateDisplayRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alternate Routes"),
        backgroundColor: const Color.fromARGB(255, 6, 11, 74),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // "From" location input
                Builder(
                  builder: (context) {
                    return TypeAheadField<NominatimPlace>(
                      textFieldConfiguration: TextFieldConfiguration(
                        controller: _fromCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.my_location),
                          labelText: "From",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      suggestionsCallback: (pattern) => _searchPlaces(pattern),
                      itemBuilder: (context, suggestion) =>
                          ListTile(title: Text(suggestion.displayName)),
                      onSuggestionSelected: (suggestion) {
                        _fromCtrl.text = suggestion.displayName;
                        if (_mapReady) {
                          _mapController.move(
                            LatLng(suggestion.lat, suggestion.lon),
                            13,
                          );
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              _mapController.move(
                                LatLng(suggestion.lat, suggestion.lon),
                                13,
                              );
                            } catch (_) {}
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                // "To" location input
                Builder(
                  builder: (context) {
                    return TypeAheadField<NominatimPlace>(
                      textFieldConfiguration: TextFieldConfiguration(
                        controller: _toCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on),
                          labelText: "To",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      suggestionsCallback: (pattern) => _searchPlaces(pattern),
                      itemBuilder: (context, suggestion) =>
                          ListTile(title: Text(suggestion.displayName)),
                      onSuggestionSelected: (suggestion) {
                        _toCtrl.text = suggestion.displayName;
                        if (_mapReady) {
                          _mapController.move(
                            LatLng(suggestion.lat, suggestion.lon),
                            13,
                          );
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              _mapController.move(
                                LatLng(suggestion.lat, suggestion.lon),
                                13,
                              );
                            } catch (_) {}
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue[800],
                    ),
                    onPressed: _loading ? null : _onCheckRoutesPressed,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _loading ? "Analyzing..." : "Find Alternate Routes",
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text("Show HIGH-RISK routes"),
                  subtitle: const Text("Hidden by default for safety"),
                  value: _showHighRiskRoutes,
                  onChanged: _confirmToggleHighRisk,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(_statusMessage, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: _displayRoutes.isEmpty && !_loading
                ? const Center(
                    child: Text(
                      "No routes yet. Enter locations and tap ‘Find Alternate Routes.’",
                    ),
                  )
                : Column(
                    children: [
                      Flexible(
                        flex: 4,
                        child: ListView.builder(
                          itemCount: _displayRoutes.length,
                          itemBuilder: (context, idx) {
                            final r = _displayRoutes[idx];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  r.risk == FloodRiskLevel.safe
                                      ? Icons.check_circle
                                      : (r.risk == FloodRiskLevel.moderate
                                            ? Icons.warning_amber_rounded
                                            : Icons.dangerous),
                                  color: r.risk == FloodRiskLevel.safe
                                      ? Colors.green
                                      : (r.risk == FloodRiskLevel.moderate
                                            ? Colors.orange
                                            : Colors.red),
                                ),
                                title: Text("Route ${idx + 1}"),
                                subtitle: Text(
                                  "${(r.distanceMeters / 1000).toStringAsFixed(1)} km • ${r.durationMinutes} min",
                                ),
                                trailing: Text(
                                  r.risk == FloodRiskLevel.safe
                                      ? "Safe"
                                      : (r.risk == FloodRiskLevel.moderate
                                            ? "Caution"
                                            : "High Risk"),
                                  style: TextStyle(
                                    color: r.risk == FloodRiskLevel.safe
                                        ? Colors.green
                                        : (r.risk == FloodRiskLevel.moderate
                                              ? Colors.orange
                                              : Colors.red),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () {
                                  final bounds = LatLngBounds.fromPoints(
                                    r.points,
                                  );
                                  if (_mapReady) {
                                    _mapController.fitBounds(
                                      bounds,
                                      options: const FitBoundsOptions(
                                        padding: EdgeInsets.all(20),
                                      ),
                                    );
                                  } else {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          try {
                                            _mapController.fitBounds(
                                              bounds,
                                              options: const FitBoundsOptions(
                                                padding: EdgeInsets.all(20),
                                              ),
                                            );
                                          } catch (_) {}
                                        });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      Flexible(
                        flex: 5,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center:
                                _displayRoutes.isNotEmpty &&
                                    _displayRoutes.first.points.isNotEmpty
                                ? _displayRoutes.first.points.first
                                : LatLng(0, 0),
                            zoom: 10,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.floodapp',
                            ),
                            PolylineLayer(
                              polylines: _displayRoutes
                                  .map(
                                    (r) => Polyline(
                                      points: r.points,
                                      strokeWidth: 5,
                                      color: r.risk == FloodRiskLevel.safe
                                          ? Colors.green
                                          : (r.risk == FloodRiskLevel.moderate
                                                ? Colors.orange
                                                : Colors.red),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class NominatimPlace {
  final String displayName;
  final double lat;
  final double lon;
  NominatimPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class RouteOption {
  final String id;
  String name;
  double distanceMeters;
  int durationMinutes;
  List<LatLng> points;
  FloodRiskLevel risk;

  RouteOption({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.durationMinutes,
    required this.points,
    this.risk = FloodRiskLevel.safe,
  });
}

class _CachedFlood {
  final FloodRiskLevel level;
  final DateTime expires;
  _CachedFlood({required this.level, required this.expires});
}
