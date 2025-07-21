import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessService {
  /// Fetch the current user's mess preference from Firestore
  static Future<int> getUserMessGender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.data()?['mess'] ?? 1;
    }
    return 0; // Default
  }

  /// Update the user's mess preference in Firestore
  static Future<void> updateUserMessGender(int newGender) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'mess': newGender,
      });
    }
  }

  /// Utility to get mess name from gender code
  static String getGenderString(int genderCode) {
    return genderCode == 0 ? "Girls" : "Boys";
  }
}
