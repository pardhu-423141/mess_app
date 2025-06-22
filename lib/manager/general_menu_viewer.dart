import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GeneralMenuViewerPage extends StatefulWidget {
  const GeneralMenuViewerPage({super.key});

  @override
  State<GeneralMenuViewerPage> createState() => _GeneralMenuViewerPageState();
}

class _GeneralMenuViewerPageState extends State<GeneralMenuViewerPage> {
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

  final Map<String, String> hostelMap = {
    "Boys": "1",
    "Girls": "0",
  };

  late String selectedDay;
  String selectedMeal = "Breakfast";
  String selectedHostel = "Boys"; // Default to Boys

  @override
  void initState() {
    super.initState();
    String today = DateFormat('EEEE').format(DateTime.now());
    selectedDay = dayMap.keys.contains(today) ? today : "Monday";
  }

  @override
  Widget build(BuildContext context) {
    String dayCode = dayMap[selectedDay]!;
    String mealCode = mealMap[selectedMeal]!;
    String hostelCode = hostelMap[selectedHostel]!;
    String menuId = "$dayCode$mealCode$hostelCode"; // Final ID format

    return Scaffold(
      appBar: AppBar(
        title: const Text("General Menu"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.pushNamed(context, '/update_general_menu'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Day Selector
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: dayMap.keys.map((day) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: selectedDay == day,
                    onSelected: (_) {
                      setState(() {
                        selectedDay = day;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Meal Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: mealMap.keys.map((meal) {
                return ChoiceChip(
                  label: Text(meal),
                  selected: selectedMeal == meal,
                  onSelected: (_) {
                    setState(() {
                      selectedMeal = meal;
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // Hostel Selector
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: hostelMap.keys.map((hostel) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ChoiceChip(
                    label: Text(hostel),
                    selected: selectedHostel == hostel,
                    onSelected: (_) {
                      setState(() {
                        selectedHostel = hostel;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Menu Details
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

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("No menu available for this time."));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data['photo'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: Image.network(
                              data['photo'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 100),
                            ),
                          ),
                        ListTile(
                          title: Text(data['description'] ?? 'No description'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text("Price: ₹${data['price']}"),
                              Text("Rating: ${data['rating']}"),
                              Text("Hostel: ${data['hostel'] == '1' ? 'Boys' : 'Girls'}"),
                            ],
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
      ),
    );
  }
}
