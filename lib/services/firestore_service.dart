// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches a single document from a specified collection.
  /// Returns the document data as a Map<String, dynamic> if it exists, otherwise null.
  Future<Map<String, dynamic>?> fetchDocument(
      String collection, String docId) async {
    try {
      final docSnapshot = await _firestore.collection(collection).doc(docId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching document $docId from $collection: $e');
      return null;
    }
  }

  /// Updates an existing document in a specified collection.
  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      debugPrint('Error updating document $docId in $collection: $e');
    }
  }

  /// Sets a document in a specified collection. If the document already exists, it will be overwritten.
  /// If it doesn't exist, a new document will be created.
  Future<void> setDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data);
    } catch (e) {
      debugPrint('Error setting document $docId in $collection: $e');
    }
  }

  /// Rolls back the reservation of extra menu items in case of payment failure or cancellation.
  Future<void> rollbackExtraMenuReservation(
      Map<String, int> extraMenuItems) async {
    for (final entry in extraMenuItems.entries) {
      final docRef = _firestore.collection('extra_menu').doc(entry.key);
      try {
        final snapshot = await docRef.get();
        final currentAvailable = snapshot.data()?['availableOrders'] ?? 0;
        await docRef.update({
          'availableOrders': currentAvailable + entry.value,
          'status': 'active', // Set status back to active
        });
      } catch (e) {
        debugPrint('Error rolling back extra menu item ${entry.key}: $e');
      }
    }
  }
}