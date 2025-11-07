import 'package:flutter/material.dart';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        backgroundColor: Colors.grey[900],
        centerTitle: true,
      ),
      backgroundColor: Colors.black,
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView( // ✅ Added scroll for small screens
          child: Text(
            '''
How to Use FloodSense

1. Download & Install
- Download the FloodSense APK from the provided link.
- Install it on your mobile device and grant necessary permissions (location, notifications).

2. View Real-Time Flood Status
- Check the Live Flood Map to see current flood risk zones:
  • Red: High risk
  • Yellow: Moderate risk
  • Green: Low risk
- Zoom and pan to view conditions in your area or other locations.

3. Receive Alerts & Safety Tips
- The app will send instant flood alerts if your area is at risk.
- Follow the step-by-step safety tips for before, during, and after floods.

4. Report Flood Incidents
- Tap the Report button to submit local flood updates (water level, blocked roads, etc.).
- Your reports help update the community database in real-time.

5. Use Offline Mode
- Even in low-network areas, FloodSense shows saved maps and essential safety information.

6. Stay Prepared
- Regularly check the app during heavy rains or flood warnings.
- Share alerts with family, friends, or neighbors to keep everyone safe.
            ''',
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
        ),
      ),
    );
  }
}
