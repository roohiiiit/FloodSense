import 'package:flutter/material.dart';

class AboutDeveloperPage extends StatelessWidget {
  const AboutDeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Developer'),
        backgroundColor: Colors.grey[900],
        centerTitle: true,
      ),
      backgroundColor: Colors.black,
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '''
Credits
App Name: FloodSense
Version: 1.0

Developed by: Codezilla

Team Members:
Rohit Fernantez
Raihan Shiras
Melvin Biju 

Special Thanks:
Mrs Devu R Unnithan
Mrs Jisha Mary Jaison 


Powered by: [ORS, OWS, Firebase, Supabase.]
          ''',

          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
