import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (reads from google-services.json automatically on Android)
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://akjngyupbtpzgafspnkz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFram5neXVwYnRwemdhZnNwbmt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ4MzE5MTUsImV4cCI6MjA3MDQwNzkxNX0.Zfklw3pesHk70h_IN6IeNXltxEJR-q6_7CzUtjR-zPI',
  );

  runApp(const FloodSenseApp());
}

class FloodSenseApp extends StatelessWidget {
  const FloodSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FloodSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue, // AppBar background color
          titleTextStyle: TextStyle(
            color: Colors.white, // White title text
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: Colors.white, // Back button and icons white
          ),
        ),
      ),
      home: const LandingPage(),
    );
  }
}
