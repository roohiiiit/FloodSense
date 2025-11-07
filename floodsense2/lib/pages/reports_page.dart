// ignore_for_file: unnecessary_type_check

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_flood_page.dart';

class ReportsPage extends StatefulWidget {
  final bool isAdmin;
  const ReportsPage({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  Future<void> fetchReports() async {
    final response = await supabase.from('reports').select();
    setState(() {
      reports = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  List<String> _parseUrls(dynamic field) {
    if (field is String && field.isNotEmpty) {
      return field.split(',').map((url) => url.trim()).toList();
    } else if (field is List) {
      return field.cast<String>();
    }
    return [];
  }

  String _getLocation(Map<String, dynamic> report) {
    final String? locationName = report['location_name'] as String?;
    if (locationName != null && locationName.trim().isNotEmpty) {
      return locationName.trim();
    }
    return "Unknown Location";
  }

  Future<void> deleteReport(int id) async {
    if (!widget.isAdmin) return; // Prevent non-admin from deleting
    await supabase.from('reports').delete().match({'id': id});
    fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flood Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchReports,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final List<String> images = _parseUrls(report['images']);
                final List<String> videos = _parseUrls(report['videos']);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getLocation(report),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(report['description'] ?? ''),
                        const SizedBox(height: 8),

                        // Images
                        if (images.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, imgIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Image.network(
                                    images[imgIndex],
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Only show delete button if admin
                        if (widget.isAdmin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                if (report['id'] != null) {
                                  deleteReport(report['id']);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportFloodPage(),
            ),
          ).then((_) => fetchReports());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
   