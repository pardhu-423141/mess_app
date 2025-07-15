import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> cleanupExpiredReservations() async {
  final firestore = FirebaseFirestore.instance;
  final expirationThreshold = DateTime.now().subtract(const Duration(minutes: 5));

  final expiredReservations = await firestore
      .collection('extra_reservations')
      .where('status', isEqualTo: 'pending')
      .where('timestamp', isLessThan: Timestamp.fromDate(expirationThreshold))
      .get();

  for (final doc in expiredReservations.docs) {
    final data = doc.data();
    final items = Map<String, int>.from(data['items'] ?? {});
    final reservationId = doc.id;

    // 1. Delete the reservation FIRST
    await firestore.collection('extra_reservations').doc(reservationId).delete();
    print('Deleted expired reservation: $reservationId');

    // 2. THEN update extra_menu stock
    final batch = firestore.batch();

    for (final entry in items.entries) {
      final itemRef = firestore.collection('extra_menu').doc(entry.key);
      final itemSnap = await itemRef.get();

      if (itemSnap.exists) {
        final itemData = itemSnap.data();
        final currentAvailable = itemData?['availableOrders'] ?? 0;

        batch.update(itemRef, {
          'availableOrders': currentAvailable + entry.value,
          'status': 'active',
        });
      }
    }

    await batch.commit();
    print('Rolled back items for reservation: $reservationId');
  }
}
