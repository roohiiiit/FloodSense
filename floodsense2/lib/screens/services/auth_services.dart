import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Signup new user
  Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    String role = 'user', // default role
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store extra user info in Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return cred.user;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      return null;
    }
  }

  // Login existing user
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase Auth login
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user profile from Firestore
      DocumentSnapshot profile = await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (!profile.exists) return null;

      var userData = profile.data() as Map<String, dynamic>;
      bool isAdmin = userData['role'] == 'admin';

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setBool('isAdmin', isAdmin);
      await prefs.setString('email', email);

      return {
        'isAdmin': isAdmin,
        'name': userData['name'],
        'email': email,
      };
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      return null;
    }
  }

  // Auto login check
  Future<Map<String, dynamic>?> checkLocalLogin() async {
    final prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!loggedIn) return null;

    String? email = prefs.getString('email');
    if (email == null) return null;

    // Get user profile from Firestore
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot profile =
        await _firestore.collection('users').doc(user.uid).get();
    if (!profile.exists) return null;

    var data = profile.data() as Map<String, dynamic>;
    return {
      'isAdmin': data['role'] == 'admin',
      'name': data['name'],
      'email': email,
    };
  }

  // Logout
  Future<void> logoutUser() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
