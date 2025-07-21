// rating_popup.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RatingPopup {
  static void show(BuildContext context) async {
    // Map to store unique items and the list of order IDs they appear in
    // Key: 'menu_type_itemId' (e.g., 'general_111', 'extra_abc')
    // Value: {'itemData': Map<String, dynamic>, 'orderIds': List<String>}
    final Map<String, Map<String, dynamic>> unratedItemsByItemId = {};
    final now = DateTime.now();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      // Handle the case where the user is not logged in.
      return;
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('user_id', isEqualTo: uid)
        .where('payment_status', isEqualTo: 'SUCCESS')
        .where('status', isEqualTo: 'served')
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final created = (data['created on'] as Timestamp?)?.toDate();

      // Consider orders served within the last 24 hours for rating (increased from 12)
      // This gives users more time to rate. Adjust as needed.
      if (created != null && now.difference(created).inHours <= 24) {
        final generalMenu = data['general_menu'];
        final extraMenu = data['extra_menu'];

        // Process General Menu Items
        if (generalMenu != null && generalMenu != 'nil' && generalMenu is List) {
          for (var item in generalMenu) {
            if (item is Map<String, dynamic> && (item['rated'] == false || item['rated'] == null)) {
              final String itemId = item['itemId'] as String;
              final String key = 'general_$itemId';

              if (!unratedItemsByItemId.containsKey(key)) {
                unratedItemsByItemId[key] = {
                  'itemData': {...item, 'menu_type': 'general', 'served_on': created},
                  'orderIds': [],
                };
              }
              unratedItemsByItemId[key]!['orderIds'].add(doc.id);
            }
          }
        }

        // Process Extra Menu Items
        if (extraMenu != null && extraMenu != 'nil' && extraMenu is List) {
          for (var item in extraMenu) {
            if (item is Map<String, dynamic> && (item['rated'] == false || item['rated'] == null)) {
              final String itemId = item['itemId'] as String;
              final String key = 'extra_$itemId';

              if (!unratedItemsByItemId.containsKey(key)) {
                unratedItemsByItemId[key] = {
                  'itemData': {...item, 'menu_type': 'extra', 'served_on': created},
                  'orderIds': [],
                };
              }
              unratedItemsByItemId[key]!['orderIds'].add(doc.id);
            }
          }
        }
      }
    }

    if (unratedItemsByItemId.isEmpty) {
      return; // No items to rate, so don't show the popup
    }

    // Fetch imageUrl for each unique unrated item
    // This makes sure we have the imageUrl before showing the dialog
    for (var entry in unratedItemsByItemId.entries) {
      final itemData = entry.value['itemData'] as Map<String, dynamic>;
      final String itemId = itemData['itemId'];
      final String menuType = itemData['menu_type'];
      String? imageUrl;

      try {
        if (menuType == 'general') {
          final doc = await FirebaseFirestore.instance.collection('general_menu').doc(itemId).get();
          if (doc.exists) {
            imageUrl = doc.data()?['imageUrl'] as String?;
          }
        } else if (menuType == 'extra') {
          final doc = await FirebaseFirestore.instance.collection('extra_menu').doc(itemId).get();
          if (doc.exists) {
            imageUrl = doc.data()?['imageUrl'] as String?;
          }
        }
        itemData['imageUrl'] = imageUrl; // Add imageUrl to itemData
      } catch (e) {
        debugPrint('Error fetching imageUrl for $itemId from $menuType: $e');
        itemData['imageUrl'] = null; // Set to null on error
      }
    }

    // Sort items so recently served items or items with no rating show up first (optional)
    final sortedItems = unratedItemsByItemId.values.toList()
      ..sort((a, b) {
        final DateTime servedA = a['itemData']['served_on'];
        final DateTime servedB = b['itemData']['served_on'];
        return servedB.compareTo(servedA); // Latest served first
      });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Your Recent Items'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded corners for AlertDialog
        titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0), // Padding for title
        contentPadding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0), // Padding for content
        content: SizedBox(
          width: double.maxFinite,
          // Limit height to 60% of screen height to allow scrolling
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView(
            shrinkWrap: true,
            children: sortedItems
                .map((itemBundle) => RatingCard(
                      itemData: itemBundle['itemData'] as Map<String, dynamic>,
                      // Explicitly cast the list of orderIds to List<String>
                      orderIds: List<String>.from(itemBundle['orderIds'] as List<dynamic>),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.deepPurple), // Use theme color
            ),
          )
        ],
      ),
    );
  }
}

class RatingCard extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final List<String> orderIds; // List of order IDs this item belongs to

  const RatingCard({
    super.key,
    required this.itemData,
    required this.orderIds,
  });

  @override
  State<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<RatingCard> {
  double _rating = 5; // Default to 5 stars
  bool _submitted = false; // To track if rating has been submitted for this card

  @override
  void initState() {
    super.initState();
    // Check if the item was already rated in the first order (assuming consistency)
    // This is a basic check. For more robustness, you'd need to verify all orders.
    // However, since we are marking ALL related orders on submit, this should be fine.
    _submitted = widget.itemData['rated'] == true;
  }

  Future<void> _submitRating() async {
    if (_submitted) return; // Prevent double submission

    final item = widget.itemData;
    final itemId = item['itemId'];
    final menuType = item['menu_type'];

    try {
      // 1. Update the overall rating statistics for the item in 'ratings' collection
      final ratingRef = FirebaseFirestore.instance.collection('ratings').doc('${menuType}_$itemId');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ratingRef);

        if (!snapshot.exists) {
          transaction.set(ratingRef, {
            'total_rating': _rating,
            'rating_count': 1,
            'avg_rating': _rating,
            'last_rated': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data()!;
          final newTotal = (data['total_rating'] as num? ?? 0) + _rating;
          final newCount = (data['rating_count'] as num? ?? 0) + 1;
          final avg = newTotal / newCount;

          transaction.update(ratingRef, {
            'total_rating': newTotal,
            'rating_count': newCount,
            'avg_rating': avg,
            'last_rated': FieldValue.serverTimestamp(),
          });
        }
      });

      // 2. Mark the specific item as rated within ALL relevant orders
      final batch = FirebaseFirestore.instance.batch();
      for (String orderId in widget.orderIds) {
        final orderDocRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        // Get the current order document to update the nested list
        final orderDoc = await orderDocRef.get();

        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          List<dynamic> menuList = [];

          if (menuType == 'general') {
            menuList = List.from(orderData['general_menu'] ?? []);
          } else if (menuType == 'extra') {
            menuList = List.from(orderData['extra_menu'] ?? []);
          }

          // Find the item in the list and mark it as rated
          for (int i = 0; i < menuList.length; i++) {
            if (menuList[i] is Map<String, dynamic> && menuList[i]['itemId'] == itemId) {
              menuList[i]['rated'] = true;
              break; // Found and updated, move to next order
            }
          }

          // Add update operation to the batch
          if (menuType == 'general') {
            batch.update(orderDocRef, {'general_menu': menuList});
          } else if (menuType == 'extra') {
            batch.update(orderDocRef, {'extra_menu': menuList});
          }
        }
      }
      await batch.commit(); // Commit all batch updates

      setState(() {
        _submitted = true;
      });

      // Optionally show a snackbar confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thanks for rating "${item['name']}"!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.itemData;
    final String imageUrl = item['imageUrl'] ?? '';
    final String name = item['name'] ?? 'Unnamed Item';

    final bool hasValidImage = imageUrl.isNotEmpty; // Uri.tryParse is handled by CachedNetworkImage

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // More prominent margin
      elevation: 4.0, // Added elevation for card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // Rounded corners for cards
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Increased padding within card
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Container (using CachedNetworkImage for better performance)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                width: 70, // Slightly larger image
                height: 70,
                color: Colors.grey[200],
                child: hasValidImage
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                )
                    : Icon(Icons.fastfood, size: 40, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 16), // More spacing
            // Expanded content for name, stars, and button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8), // More spacing
                  // Star rating row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) => GestureDetector(
                      onTap: _submitted ? null : () {
                        setState(() => _rating = index + 1.0);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber, // Cred uses amber/yellow for stars
                          size: 28, // Slightly larger stars
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 12), // More spacing
                  // Submit button or "Thanks for rating!" message
                  _submitted
                      ? Text(
                    "Thanks for rating!",
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  )
                      : SizedBox(
                    width: double.infinity, // Button takes full available width
                    child: ElevatedButton(
                      onPressed: _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor, // Use primary theme color
                        foregroundColor: Colors.white, // White text on button
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0), // Rounded button corners
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10), // Padding
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        elevation: 3, // Button elevation
                      ),
                      child: const Text("Submit Rating"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}