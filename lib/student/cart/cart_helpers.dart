import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool isWithinRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
  final nowMin = now.hour * 60 + now.minute;
  final startMin = start.hour * 60 + start.minute;
  final endMin = end.hour * 60 + end.minute; // Corrected: Should be end.minute
  return nowMin >= startMin && nowMin <= endMin;
}


Future<bool> reserveExtraItems(String userId, Map<String, int> extraMenuItems) async {
  final firestore = FirebaseFirestore.instance;
  final reservationRef = firestore.collection('extra_reservations').doc(userId);

  try {
    await firestore.runTransaction((transaction) async {
      // 1. Handle any existing PENDING reservation for this user FIRST.
      final existingReservationSnap = await transaction.get(reservationRef);
      if (existingReservationSnap.exists && existingReservationSnap['status'] == 'pending') {
        final oldItems = Map<String, dynamic>.from(existingReservationSnap['items'] ?? {});
        for (final entry in oldItems.entries) {
          final rollbackRef = firestore.collection('extra_menu').doc(entry.key);
          transaction.update(rollbackRef, {
            'availableOrders': FieldValue.increment(entry.value as int),
            'status': 'active',
          });
        }

        // 🔴 Delete old reservation so it won't be picked up by cleanupExpiredReservations
        transaction.delete(reservationRef);
      }

      // 2. Read current item documents
      final Map<String, DocumentSnapshot> currentItemSnaps = {};
      for (var entry in extraMenuItems.entries) {
        final docRef = firestore.collection('extra_menu').doc(entry.key);
        final docSnap = await transaction.get(docRef);
        currentItemSnaps[entry.key] = docSnap;
      }

      // 3. Validate availability and prepare update map
      final Map<String, dynamic> updatesForItems = {};
      for (var entry in extraMenuItems.entries) {
        final itemId = entry.key;
        final requested = entry.value;

        final itemSnap = currentItemSnaps[itemId];
        if (!itemSnap!.exists) {
          throw Exception('Item $itemId not found in menu.');
        }

        final available = itemSnap['availableOrders'] ?? 0;

        if (available < requested) {
          throw Exception('Not enough stock for $itemId. Available: $available, Requested: $requested');
        }

        updatesForItems[itemId] = {
          'availableOrders': available - requested,
          if ((available - requested) <= 0) 'status': 'inactive',
        };
      }

      // 4. Apply item stock updates
      updatesForItems.forEach((itemId, data) {
        transaction.update(firestore.collection('extra_menu').doc(itemId), data);
      });

      // 5. Create the new reservation
      transaction.set(reservationRef, {
        'user_id': userId,
        'items': extraMenuItems,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    return true;
  } catch (e) {
    debugPrint('Reservation failed: $e');
    return false;
  }
}

Future<void> markReservationCompleted(String userId) async {
  await FirebaseFirestore.instance
      .collection('extra_reservations')
      .doc(userId)
      .update({'status': 'completed'});
}

Future<void> rollbackExtraItems(Map<String, int> extraMenuItems) async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch(); // Use a batch for atomic updates

  for (var entry in extraMenuItems.entries) {
    final docRef = firestore.collection('extra_menu').doc(entry.key);
    batch.update(docRef, {
      'availableOrders': FieldValue.increment(entry.value as int),
      'status': 'active',
    });
  }
  await batch.commit();
}

Future<void> deleteReservation(String userId) async {
  await FirebaseFirestore.instance.collection('extra_reservations').doc(userId).delete();
}