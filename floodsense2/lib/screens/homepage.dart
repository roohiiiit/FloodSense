import 'package:flutter/material.dart';

// Pages
import 'package:floodsense2/pages/crowdsource.dart';
import 'package:floodsense2/pages/loading_screen.dart';
import 'package:floodsense2/pages/flooddetection.dart';
import 'package:floodsense2/pages/livemap.dart';
import 'package:floodsense2/pages/howtouse.dart';
import 'package:floodsense2/pages/aboutdeveloper.dart';
import 'package:floodsense2/pages/alternateroutes.dart';
import 'package:floodsense2/pages/bg.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 46, 45, 45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.info_outline),
                label: const Text('How to Use This App'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HowToUsePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text('About Developer'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutDeveloperPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'FloodSense',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 6, 11, 74),
          centerTitle: true,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                'Welcome to FloodSense!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                    children: [
                      buildGridItem(
                        context,
                        title: 'Flood Detection',
                        subtitle: 'Check Risk',
                        icon: Icons.water_drop,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoadingScreen(
                                nextPage: const FloodDetectionPage(),
                              ),
                            ),
                          );
                        },
                      ),
                      buildGridItem(
                        context,
                        title: 'Live Map',
                        subtitle: 'Flood Zones',
                        icon: Icons.map,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoadingScreen(
                                nextPage: const LiveMap(),
                              ),
                            ),
                          );
                        },
                      ),
                      buildGridItem(
                        context,
                        title: 'Safe Routes',
                        subtitle: 'Avoid Floods',
                        icon: Icons.route,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoadingScreen(
                                nextPage: const AlternateRoutesPage(),
                              ),
                            ),
                          );
                        },
                      ),
                      buildGridItem(
                        context,
                        title: 'Crowd Data',
                        subtitle: 'User Reports',
                        icon: Icons.people_alt,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoadingScreen(
                                nextPage: const LoginPage(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color.fromARGB(255, 6, 11, 74),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
          onTap: (index) {
            if (index == 1) {
              _showMoreOptions(context);
            }
          },
        ),
      ),
    );
  }

  Widget buildGridItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 6, 11, 74),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
