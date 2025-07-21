import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'meal_utils.dart';
import 'menu_card.dart';
import 'cart_notifier.dart';

class ExtraMenuPage extends StatelessWidget {
  final Function(String, String) onAddToCart;
  final Function(String, String) onRemoveFromCart;
  final String userGender;

  const ExtraMenuPage({
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.userGender,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double cardHeight = mediaQuery.size.height / 4;
    final double cardWidth = (mediaQuery.size.width - 40) / 2;
    final now = DateTime.now();
    final mealType = getCurrentMealType();
    final actualDay = getCurrentActualDayString();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Daily Meal: $mealType ($actualDay)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuSection(
            context,
            'general_menu',
            mealType,
            actualDay,
            cardHeight,
            cardWidth,
            true,
          ),
          _buildMenuSection(
            context,
            'extra_menu',
            mealType,
            actualDay,
            cardHeight,
            cardWidth,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    String collection,
    String mealType,
    String day,
    double cardHeight,
    double cardWidth,
    bool isGeneral,
  ) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        List<QueryDocumentSnapshot> docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (isGeneral) {
            return data['hostel']?.toString() == userGender &&
                   getMealTypeFromCode(doc.id) == mealType &&
                   getDayStringFromIdDigit(doc.id) == day;
          } else {
            final start = (data['startTime'] as Timestamp?)?.toDate();
            final end = (data['endTime'] as Timestamp?)?.toDate();
            final status = data['status'];
            return data['gender']?.toString() == userGender &&
                   data['mealType'] == mealType &&
                   start != null &&
                   end != null &&
                   now.isAfter(start) &&
                   now.isBefore(end) &&
                   status == 'active';
          }
        }).toList();

        // ✅ Sorting logic applied here
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final int aOrders = aData['availableOrders'] ?? 1; // default to 1 for general menu
          final int bOrders = bData['availableOrders'] ?? 1;
          final double aRating = (aData['rating'] as num?)?.toDouble() ?? 0.0;
          final double bRating = (bData['rating'] as num?)?.toDouble() ?? 0.0;

          if (aOrders == 0 && bOrders != 0) return 1;
          if (bOrders == 0 && aOrders != 0) return -1;

          return bRating.compareTo(aRating); // descending
        });

        if (docs.isEmpty) return const SizedBox.shrink();

        return ValueListenableBuilder<Map<String, int>>(
          valueListenable: cartNotifier,
          builder: (context, cartValue, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final price = data['price']?.toString() ?? '0';
                  final description = data['description'] ?? '';
                  final imageUrl = data['imageUrl'] as String?;
                  final double? rating = (data['rating'] as num?)?.toDouble();

                  DateTime? closeTime;
                  bool isActive = true;
                  bool inStock = true;

                  if (isGeneral) {
                    closeTime = getMealClosingTime(mealType);
                  } else {
                    final start = (data['startTime'] as Timestamp?)?.toDate();
                    final end = (data['endTime'] as Timestamp?)?.toDate();
                    closeTime = end;
                    inStock = (data['availableOrders'] ?? 0) > 0;
                    isActive = start != null && end != null && now.isAfter(start) && now.isBefore(end) && inStock;
                  }

                  final cartKey = '${collection}_${doc.id}';
                  final count = cartValue[cartKey] ?? 0;

                  return MenuItemCard(
                    itemName: mealType,
                    itemActualName: data['name'] ?? 'Unnamed',
                    itemPrice: price,
                    imageUrl: imageUrl,
                    itemCount: count,
                    isActive: isActive,
                    isAvailableInStock: inStock,
                    canAddToCart: isActive && (collection == 'general_menu' || count < (data['availableOrders'] ?? 0)),
                    onAdd: () => onAddToCart(doc.id, collection),
                    onRemove: () => onRemoveFromCart(doc.id, collection),
                    description: description,
                    bookingClosingTime: closeTime,
                    cardHeight: cardHeight,
                    cardWidth: cardWidth,
                    isGeneralMenuItem: isGeneral,
                    rating: rating,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
