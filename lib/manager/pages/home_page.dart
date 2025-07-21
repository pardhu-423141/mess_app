import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../add_extra_menu.dart';
import '../../utils/meal_utils.dart'; // Assuming this utility exists

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1 for Male, 0 for Female
  int _userGender = 1; // This will be fetched from Firestore for the logged-in user
  int _selectedGender=1; // The gender currently being viewed (can be different from _userGender)
  String? _currentMealType;

  @override
  void initState() {
    super.initState();
    _determineCurrentMealType();
    _checkAndDeactivateExpiredItems(); // Call the new function here
    _fetchUserGenderAndSetDefault();
  }

  // Mock function to simulate fetching user gender from Firestore
  // In a real app, you would use Firebase Auth to get the current user's UID,
  // then fetch their document from the 'users' collection.
  Future<void> _fetchUserGenderAndSetDefault() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _userGender = userDoc.data()?['Sex'] ?? 0; // Assuming 'mess' field exists for gender
      } else {
        _userGender = 0; // Default if user data not found
      }
    } else {
      _userGender = 0; // Default if no user logged in
    }

    setState(() {
      _selectedGender = _userGender; // Initially show menus for the user's own gender
    });
  }

  

  void _determineCurrentMealType() {
    final nowTimeOfDay = TimeOfDay.now();
    _currentMealType = MealUtils.getMealNameForCurrentTime(nowTimeOfDay);
  }

  /// Deactivates extra menu items if their end time has passed.
  Future<void> _checkAndDeactivateExpiredItems() async {
    final now = DateTime.now();
    final querySnapshot = await FirebaseFirestore.instance.collection('extra_menu')
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final endTime = (data['endTime'] as Timestamp?)?.toDate();

      if (endTime != null && now.isAfter(endTime)) {
        await FirebaseFirestore.instance.collection('extra_menu').doc(doc.id).update({
          'status': 'inactive',
        });
        debugPrint('Deactivated expired item: ${data['name']}');
      }
    }
  }


  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  String _getGenderString(int genderCode) {
    return genderCode == 1 ? "Boys" : "Girls";
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _selectedGender is initialized before building the UI
    if (!mounted ) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Extra Menu Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF1A1A1A), // Consistent dark background
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('extra_menu')
            .orderBy('startTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)));
          }

          final docs = snapshot.data?.docs ?? [];

          final filteredMenus = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final menuGender = data['gender'];
            final menuMealType = data['mealType'] as String?;

            final isSameGender = menuGender == _selectedGender;
            final isCurrentMealType = _currentMealType == null || menuMealType == _currentMealType;

            return isSameGender && isCurrentMealType;
          }).toList();

          // Sort active menus first, then inactive
          filteredMenus.sort((a, b) {
            final aStatus = (a.data() as Map<String, dynamic>)['status'] ?? 'inactive';
            final bStatus = (b.data() as Map<String, dynamic>)['status'] ?? 'inactive';

            if (aStatus == 'active' && bStatus != 'active') {
              return -1; // a comes before b
            } else if (aStatus != 'active' && bStatus == 'active') {
              return 1; // b comes before a
            }
            // If both are active or both are inactive, maintain original order (by startTime)
            return 0;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Mess Indicator
                    Text(
                      "You are viewing menus for the ${_getGenderString(_selectedGender)} Mess.",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_currentMealType != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          "Current Meal Type: $_currentMealType",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Displaying menus
              if (filteredMenus.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "No extra menus found for the selected gender and current meal type.",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (filteredMenus.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredMenus.length + 1, // +1 for the "Add Extra Menu" button
                    itemBuilder: (context, index) {
                      if (index == filteredMenus.length) {
                        // This is the last item: the "Add Extra Menu" button
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text("Add Extra Menu"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddExtraMenuPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        );
                      }

                      // Otherwise, build a regular menu item card
                      final doc = filteredMenus[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;
                      final name = data['name'] ?? 'Unnamed';
                      final price = data['price'] ?? 'N/A';
                      final description = data['description'] ?? 'No description';
                      final bookingsLeft = data['availableOrders'] ?? 'N/A';
                      final imageUrl = data['imageUrl'] ?? '';
                      final startTime = (data['startTime'] as Timestamp?)?.toDate();
                      final endTime = (data['endTime'] as Timestamp?)?.toDate();
                      final status = data['status'] ?? 'inactive';
                      final isActive = status == 'active';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15.0),
                            gradient: LinearGradient(
                              colors: [
                                isActive ? const Color(0xFF2C2C2C) : const Color(0xFF3A2A2A),
                                isActive ? const Color(0xFF3A3A3A) : const Color(0xFF4A3A3A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Stack(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.fastfood, size: 70, color: Colors.white54),
                                        )
                                      : const Icon(Icons.fastfood, size: 70, color: Colors.white54),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Price: ₹$price",
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    Text(
                                      "Remaining Bookings: $bookingsLeft",
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    Text(
                                      "Description: $description",
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (startTime != null && endTime != null)
                                      Text(
                                        "Time: ${formatTime(startTime)} - ${formatTime(endTime)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          if (isActive) {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text("Confirm Deactivation"),
                                                content: const Text("Are you sure you want to deactivate this item?"),
                                                actions: [
                                                  TextButton(
                                                    child: const Text("Cancel"),
                                                    onPressed: () => Navigator.pop(context, false),
                                                  ),
                                                  ElevatedButton(
                                                    child: const Text("Confirm"),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.redAccent,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await FirebaseFirestore.instance
                                                  .collection('extra_menu')
                                                  .doc(docId)
                                                  .update({'status': 'inactive'});
                                            }
                                          } else {
                                            // Handle activation logic
                                            showDialog(
                                              context: context,
                                              builder: (_) => EditDialog(
                                                docId: docId,
                                                data: data,
                                                isActive: isActive,
                                                mealType: _currentMealType, // Pass current meal type
                                              ),
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isActive ? Colors.orangeAccent : Colors.lightGreenAccent,
                                          side: BorderSide(color: isActive ? Colors.orangeAccent : Colors.lightGreenAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(isActive ? "Deactivate" : "Activate"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => EditDialog(
                                        docId: docId,
                                        data: data,
                                        isActive: isActive,
                                        mealType: _currentMealType, // Pass current meal type
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---
class EditDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isActive;
  final String? mealType; // Added to get the current meal type

  const EditDialog({
    super.key,
    required this.docId,
    required this.data,
    required this.isActive,
    this.mealType,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late TextEditingController bookingsController;
  late int _selectedGenderEdit; // Only used for editing existing active items

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.data['name']);
    priceController = TextEditingController(text: widget.data['price'].toString());
    descriptionController = TextEditingController(text: widget.data['description'] ?? '');

    // For activation, don't pre-fill bookings or gender
    if (widget.isActive) {
      bookingsController = TextEditingController(text: widget.data['availableOrders'].toString());
      _selectedGenderEdit = widget.data['gender'] ?? 0;
    } else {
      bookingsController = TextEditingController(text: ''); // Empty for activation
      _selectedGenderEdit = widget.data['gender'] ?? 0; // Keep the existing gender for activation
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    bookingsController.dispose();
    super.dispose();
  }

  // Helper to get meal type closing time
  DateTime _getMealClosingTime(String? mealType) {
    final now = DateTime.now();
    DateTime closingTime = now; // Default to now if no meal type

    // Use MealUtils to get the closing time for the current meal type
    // This assumes MealUtils has a method like `getClosingTimeForMeal(String mealType)`
    // You'll need to implement this in your meal_utils.dart
    switch (mealType) {
      case 'Breakfast':
        closingTime = DateTime(now.year, now.month, now.day, 10, 0); // 10:00 AM
        break;
      case 'Lunch':
        closingTime = DateTime(now.year, now.month, now.day, 14, 30); // 2:30 PM
        break;
      case 'Snacks':
        closingTime = DateTime(now.year, now.month, now.day, 18, 0); // 6:00 PM
        break;
      case 'Dinner':
        closingTime = DateTime(now.year, now.month, now.day, 22, 0); // 10:00 PM
        break;
      default:
      // Fallback or error handling if mealType is unknown
        closingTime = DateTime(now.year, now.month, now.day, 23, 59); // End of day
        break;
    }
    return closingTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      title: Text(
        widget.isActive ? "Edit Menu Item" : "Activate Menu Item",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
        ),
      ),
      contentTextStyle: const TextStyle(
        color: Colors.white70,
        fontFamily: 'Montserrat',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.data['imageUrl'] != null && widget.data['imageUrl'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    widget.data['imageUrl'],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.fastfood, size: 120, color: Colors.white54),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 15.0),
                child: Icon(Icons.fastfood, size: 120, color: Colors.white54),
              ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              readOnly: !widget.isActive, // Make name read-only if activating
              style: TextStyle(color: !widget.isActive ? Colors.white54 : Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              readOnly: !widget.isActive, // Make description read-only if activating
              style: TextStyle(color: !widget.isActive ? Colors.white54 : Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: bookingsController,
              decoration: InputDecoration(
                labelText: widget.isActive ? 'Remaining Bookings' : 'Max Available Orders (to activate)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            // Gender selection only visible if editing an active item
            if (widget.isActive) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Target Gender:",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: const Text("Male"),
                    selected: _selectedGenderEdit == 1,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedGenderEdit = 1;
                        });
                      }
                    },
                    selectedColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({MaterialState.selected}),
                    labelStyle: TextStyle(
                        color: _selectedGenderEdit == 0 ? Colors.white : Colors.white70),
                    backgroundColor: const Color(0xFF3A3A3A),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Female"),
                    selected: _selectedGenderEdit == 0,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedGenderEdit = 0;
                        });
                      }
                    },
                    selectedColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({MaterialState.selected}),
                    labelStyle: TextStyle(
                        color: _selectedGenderEdit == 1 ? Colors.white : Colors.white70),
                    backgroundColor: const Color(0xFF3A3A3A),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            String newStatus = widget.data['status'] ?? 'inactive';
            final int parsedBookings = int.tryParse(bookingsController.text) ?? 0;

            DateTime? newStartTime = widget.data['startTime']?.toDate();
            DateTime? newEndTime = widget.data['endTime']?.toDate();

            if (widget.isActive) {
              // If currently active, we are editing it. Status can become inactive if bookings are 0.
              if (parsedBookings == 0) {
                newStatus = 'inactive';
              } else {
                newStatus = 'active';
              }
            } else {
              // If currently inactive, we are activating it.
              if (parsedBookings > 0) {
                newStatus = 'active';
                newStartTime = DateTime.now(); // Set start time to current time
                newEndTime = _getMealClosingTime(widget.mealType); // Set end time to meal type closing time
              } else {
                newStatus = 'inactive'; // If 0 bookings, keep it inactive
              }
            }

            await FirebaseFirestore.instance.collection('extra_menu').doc(widget.docId).update({
              'name': nameController.text,
              'price': double.tryParse(priceController.text) ?? 0,
              'description': descriptionController.text,
              'availableOrders': parsedBookings,
              'gender': _selectedGenderEdit, // Keep original gender for activation
              'status': newStatus,
              'startTime': newStartTime != null ? Timestamp.fromDate(newStartTime) : null,
              'endTime': newEndTime != null ? Timestamp.fromDate(newEndTime) : null,
            });

            if (mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Save"),
        ),
      ],
    );
  }
}