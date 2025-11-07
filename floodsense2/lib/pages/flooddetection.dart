import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class FloodDetectionPage extends StatefulWidget {
  const FloodDetectionPage({super.key});

  @override
  _FloodDetectionPageState createState() => _FloodDetectionPageState();
}

class _FloodDetectionPageState extends State<FloodDetectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  double? _selectedLat;
  double? _selectedLon;
  String? _selectedPlaceName;
  String _floodStatus = "";
  bool _isSearching = false;
  bool _isCheckingFlood = false;

  Future<void> searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _floodStatus = "";
    });

    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch search results.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error searching location: $e")),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> checkFloodRisk() async {
    if (_selectedLat == null || _selectedLon == null) return;

    setState(() {
      _isCheckingFlood = true;
      _floodStatus = "";
    });

    // NOTE: It is highly recommended to store API keys securely and not hardcode them.
    const apiKey = "c0c37a7969052eb7cc9e7fe020a96981";
    final weatherUrl = Uri.parse(
        "https://api.openweathermap.org/data/2.5/forecast?lat=$_selectedLat&lon=$_selectedLon&appid=$apiKey&units=metric");

    try {
      final response = await http.get(weatherUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double totalRain = 0;

        for (var forecast in data["list"]) {
          if (forecast["rain"] != null && forecast["rain"]["3h"] != null) {
            totalRain += (forecast["rain"]["3h"] as num).toDouble();
          }
        }

        // This is a simplified threshold. Real-world flood risk depends on many factors.
        const floodThreshold = 100.0; 

        setState(() {
          if (totalRain > floodThreshold) {
            _floodStatus =
                "⚠ High Flood Risk! Total Rain: ${totalRain.toStringAsFixed(1)} mm";
          } else {
            _floodStatus =
                "✅ Safe. Total Rain: ${totalRain.toStringAsFixed(1)} mm";
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch weather data.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching flood data: $e")),
      );
    } finally {
      setState(() {
        _isCheckingFlood = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lottie animated background
        Positioned.fill(
          child: Lottie.asset(
            'assets/animated_bg.json', // Ensure you have this file in your assets
            fit: BoxFit.cover,
            repeat: true,
          ),
        ),

        // Transparent scaffold
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("Flood Detection"),
            backgroundColor: Colors.blue[800],
            elevation: 0, // Remove shadow for a cleaner look
          ),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white), // white text
                  decoration: InputDecoration(
                    labelText: "Search location",
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              searchLocation(_searchController.text);
                            },
                          ),
                  ),
                  onChanged: (value) {
                    // This triggers the live search for suggestions
                    if (value.length >= 3) {
                      searchLocation(value);
                    } else {
                      setState(() {
                        _searchResults.clear();
                      });
                    }
                  },
                ),

                // Dropdown suggestions
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 200), // Prevent list from being too long
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          title: Text(
                            place["display_name"],
                            // ✨ FIX: Changed text color for better contrast against the light background
                            style: const TextStyle(color: Colors.black87), 
                          ),
                          onTap: () {
                            setState(() {
                              _selectedLat = double.parse(place["lat"]);
                              _selectedLon = double.parse(place["lon"]);
                              _selectedPlaceName = place["display_name"];
                              _searchResults.clear();
                              _searchController.text = _selectedPlaceName!;
                              _floodStatus = "";
                              // Hide keyboard
                              FocusScope.of(context).unfocus();
                            });
                            checkFloodRisk();
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),
                
                // This part expands to fill the remaining space
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_selectedPlaceName != null && _floodStatus.isEmpty && !_isCheckingFlood)
                           const Text(
                              "Tap a suggestion to check the flood risk.",
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                           ),
                  
                        if (_isCheckingFlood) const CircularProgressIndicator(color: Colors.white),

                        if (_floodStatus.isNotEmpty && !_isCheckingFlood) ...[
                          const Text(
                            "Flood Risk Assessment",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _selectedPlaceName!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Divider(color: Colors.white54, height: 20),
                                Text(
                                  _floodStatus,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _floodStatus.contains("High")
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}