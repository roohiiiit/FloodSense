import 'package:flutter/material.dart';
import 'package:floodsense2/screens/services/auth_services.dart';
import 'package:floodsense2/pages/crowdsource.dart';
import 'package:floodsense2/pages/report_flood_page.dart';
import 'package:floodsense2/pages/reports_page.dart';
import 'package:floodsense2/pages/bg.dart'; // Added for motion background
import 'package:floodsense2/pages/crowdsource.dart'; // Make sure you have your LoginPage import

class LandingPage extends StatefulWidget {
  const LandingPage(LoginPage loginPage, {super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final AuthService _authService = AuthService();
  bool isLoading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    var userData = await _authService.checkLocalLogin();
    if (!mounted) return;
    if (userData != null) {
      setState(() {
        isAdmin = userData['isAdmin'] ?? false;
        isLoading = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBackgroundWrapper( // Wrap the page in motion background
      child: Scaffold(
        backgroundColor: Colors.transparent, // So background shows
        appBar: AppBar(
          title: const Text(
  "FloodSense",
  style: TextStyle(
    color: Colors.white, // ✅ Put color here
    fontWeight: FontWeight.bold,
  ),
),

          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 6, 11, 74),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                icon: Icons.add_location_alt,
                text: "Report Flood",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportFloodPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                icon: Icons.list_alt,
                text: "View Reports",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportsPage(isAdmin: isAdmin),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 80,
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 6, 11, 74).withOpacity(0.85), // Slight transparency
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }
}
