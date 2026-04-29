import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      print("=== GOOGLE SIGN-IN START ===");

      // Use Firebase Auth's Google provider directly
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({
        'prompt': 'select_account'
      });

      print("Signing in with Firebase Google provider...");
      final UserCredential userCredential =
          await _auth.signInWithProvider(googleProvider);

      final User? user = userCredential.user;

      if (user != null) {
        print("Firebase sign-in SUCCESS: ${user.uid}");
        print("Email: ${user.email}");
        print("Display Name: ${user.displayName}");
        await _createOrUpdateUserProfile(user);
      } else {
        print("ERROR: Firebase user is null after sign-in");
      }

      print("=== GOOGLE SIGN-IN END ===");
      return user;
    } catch (e, stackTrace) {
      print("=== GOOGLE SIGN-IN ERROR ===");
      print("Error: $e");
      print("Stack trace: $stackTrace");
      print("===========================");
      return null;
    }
  }

  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        print("Creating new user profile for ${user.uid}");

        final userProfile = UserProfile(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          friends: [],
          friendRequests: [],
          sentRequests: [],
          createdAt: DateTime.now(),
        );

        await userDoc.set(userProfile.toJson());
        print("User profile created successfully");
      } else {
        print("User profile already exists");
      }
    } catch (e) {
      print("Error creating/updating user profile: $e");
    }
  }

  Future<void> signOut() async {
    try {
      print("Signing out...");
      await _auth.signOut();
      print("Signed out successfully");
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
