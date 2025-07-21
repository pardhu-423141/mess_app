import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/meal_utils.dart'; // Ensure this file has getMealTimings and TimeRange

class GeneralMenuPage extends StatefulWidget {
  const GeneralMenuPage({super.key});

  @override
  State<GeneralMenuPage> createState() => _GeneralMenuPageState();
}

class _GeneralMenuPageState extends State<GeneralMenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userGender = '1'; // Default to boys, will be replaced by actual fetch
  bool _isLoading = true; 
  final Map<String, String> dayMap = {
    "Monday": "1",
    "Tuesday": "2",
    "Wednesday": "3",
    "Thursday": "4",
    "Friday": "5",
    "Saturday": "6",
    "Sunday": "7",
  };

  final Map<String, String> mealMap = {
    "Breakfast": "1",
    "Lunch": "2",
    "Snacks": "3",
    "Dinner": "4",
  };

  late String selectedDay;
  late String selectedMeal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    String today = DateFormat('EEEE').format(DateTime.now());
    selectedDay = dayMap.containsKey(today) ? today : "Monday";
    selectedMeal = _getCurrentMeal();

    _fetchUserGender();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserGender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          if (mounted) {
            setState(() {
              _userGender = userData['mess']?.toString() ?? '1';
              _isLoading = false; // <-- Done loading
            });
          }
        } else {
          print("User document does not exist or is empty.");
          if (mounted) {
            setState(() {
              _userGender = '1';
              _isLoading = false; // <-- Done loading
            });
          }
        }
      } catch (e) {
        print("Error fetching user gender: $e");
        if (mounted) {
          setState(() {
            _userGender = '1';
            _isLoading = false; // <-- Done loading
          });
        }
      }
    } else {
      print("No user logged in.");
      if (mounted) {
        setState(() {
          _userGender = '1';
          _isLoading = false; // <-- Done loading
        });
      }
    }
  }


  String _getCurrentMeal() {
    final now = TimeOfDay.now();
    final mealTimings = getMealTimings();
    for (var entry in mealTimings.entries) {
      final start = entry.value.start;
      final end = entry.value.end;
      if (_isNowInRange(now, start, end)) {
        return entry.key;
      }
    }
    return "Breakfast";
  }

  bool _isNowInRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    String dayCode = dayMap[selectedDay]!;
    String mealCode = mealMap[selectedMeal]!;
    String menuId = "$dayCode$mealCode$_userGender";

    return Scaffold(
      appBar: AppBar(
        title: const Text("General Menu"),
      ),
      body: Column(
        children: [
          // Day Selector (already horizontally scrollable)
          Container(
            height: 60,
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: dayMap.keys.map((day) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(
                      day,
                      style: TextStyle(
                        color: selectedDay == day ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: selectedDay == day,
                    selectedColor: Theme.of(context).primaryColor,
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selectedDay == day
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() => selectedDay = day);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Meal Selector (now horizontally scrollable)
          Container(
            height: 60, // Fixed height for horizontal list
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mealMap.keys.map((meal) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(
                      meal,
                      style: TextStyle(
                        color: selectedMeal == meal ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: selectedMeal == meal,
                    selectedColor: Theme.of(context).primaryColor,
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selectedMeal == meal
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() => selectedMeal = meal);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Menu Display Area
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('general_menu')
                  .doc(menuId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading menu: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "No menu available for ${selectedMeal} on ${selectedDay} for gender code $_userGender.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final String itemName = data['name']?.toString() ?? selectedMeal;
                final String description = data['description']?.toString() ?? 'No description available.';
                final String price = data['price']?.toString() ?? 'N/A';
                final String? imageUrl = data['imageUrl']?.toString();
                final double? rating = (data['rating'] as num?)?.toDouble();

                final List<String> descriptionItems = description
                    .split('+')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image with Price Overlay
                      Stack(
                        alignment: Alignment.bottomRight, // Align price to bottom right
                        children: [
                          Container(
                            width: double.infinity, // Take full width
                            height: MediaQuery.of(context).size.width * 0.64, // Square shape (e.g., 80% of screen width)
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(15), // Rounded corners for the image container
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 2,
                                  blurRadius: 7,
                                  offset: const Offset(0, 3), // changes position of shadow
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias, // Clip children to rounded corners
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                    errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                              child: Icon(Icons.broken_image,
                                                  size: 80, color: Colors.grey)),
                                        ),
                                  )
                                : const Center(
                                    child: Icon(Icons.fastfood,
                                        size: 100, color: Colors.grey),
                                  ),
                          ),
                          // Price overlaid on the image
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.9), // Semi-transparent background
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                "₹$price",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16), // Space between image and details

                      // Details Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0), // Slight horizontal padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemName,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColorDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (descriptionItems.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...descriptionItems.map((item) => Padding(
                                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                                    child: Text(
                                      '• $item',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  )).toList(),
                                ],
                              )
                            else
                              Text(
                                'No description available.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (rating != null && rating > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end, // Align rating to the right
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}