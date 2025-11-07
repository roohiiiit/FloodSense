import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportFloodPage extends StatefulWidget {
  const ReportFloodPage({super.key});

  @override
  State<ReportFloodPage> createState() => _ReportFloodPageState();
}

class _ReportFloodPageState extends State<ReportFloodPage> {
  final TextEditingController descController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<XFile> selectedMedia = [];
  bool isLoading = false;
  List<String> locationSuggestions = [];
  Timer? _debounce;

  final supabase = Supabase.instance.client;

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        selectedMedia.addAll(pickedFiles);
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedVideo =
        await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedVideo != null) {
      setState(() {
        selectedMedia.add(pickedVideo);
      });
    }
  }

  void _onLocationChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _fetchLocationSuggestions(query);
      } else {
        setState(() {
          locationSuggestions.clear();
        });
      }
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'floodsense-app'
      });
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          locationSuggestions = data
              .map((item) => item["display_name"] as String)
              .toList();
        });
      } else {
        setState(() {
          locationSuggestions.clear();
        });
      }
    } catch (e) {
      setState(() {
        locationSuggestions.clear();
      });
    }
  }

  void _selectLocation(String suggestion) {
    locationController.text = suggestion;
    setState(() {
      locationSuggestions.clear();
    });
  }

  Future<void> _submitReport() async {
    if (descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter description')),
      );
      return;
    }

    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter location')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Separate images and videos
      List<String> imagePaths = [];
      List<String> videoPaths = [];

      for (var file in selectedMedia) {
        final ext = file.path.split('.').last.toLowerCase();
        if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          videoPaths.add(file.path);
        } else {
          imagePaths.add(file.path);
        }
      }

      // Convert lists to JSON strings
      String imagesStr = imagePaths.isNotEmpty ? jsonEncode(imagePaths) : '';
      String? videosStr = videoPaths.isNotEmpty ? jsonEncode(videoPaths) : null;

      final data = {
        'description': descController.text.trim(),
        'location_name': locationController.text.trim(),
        'images': imagesStr,
        'videos': videosStr,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Supabase v2 insert + select to get inserted row
      final inserted = await supabase.from('reports').insert(data).select();

      if (inserted.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Insert returned no data');
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          selectedMedia.clear();
          descController.clear();
          locationController.clear();
        });
      }
    }
  }

  Widget _buildMediaPreview() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: selectedMedia.asMap().entries.map((entry) {
        int index = entry.key;
        XFile file = entry.value;
        final ext = file.path.split('.').last.toLowerCase();

        Widget mediaWidget;

        if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          mediaWidget = Container(
            width: 100,
            height: 100,
            color: Colors.black12,
            child: const Icon(Icons.videocam, size: 40, color: Colors.black54),
          );
        } else {
          mediaWidget = Image.file(
            File(file.path),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        }

        return Stack(
          children: [
            mediaWidget,
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedMedia.removeAt(index);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Flood")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: locationController,
              onChanged: _onLocationChanged,
              decoration: const InputDecoration(
                labelText: "Location",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.location_on),
              ),
            ),
            if (locationSuggestions.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: locationSuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(locationSuggestions[index]),
                      onTap: () => _selectLocation(locationSuggestions[index]),
                    );
                  },
                ),
              ),
            const SizedBox(height: 15),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _pickImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Add Images'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Add Video'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (selectedMedia.isNotEmpty) _buildMediaPreview(),
            const SizedBox(height: 25),
            if (isLoading)
              const LinearProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  child: const Text("Submit Report"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
