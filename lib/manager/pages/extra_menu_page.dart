import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../add_extra_menu.dart'; // contains getMealTimings()

class ExtraMenuPage extends StatelessWidget {
  const ExtraMenuPage({super.key});

  String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Extra Menu Manager"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Inactive"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('extra_menu')
              .orderBy('startTime')
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            final activeMenus = <QueryDocumentSnapshot>[];
            final inactiveMenus = <QueryDocumentSnapshot>[];

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final start = (data['startTime'] as Timestamp?)?.toDate();
              final end = (data['endTime'] as Timestamp?)?.toDate();
              final status = data['status'] ?? '';

              final isActive = start != null &&
                  end != null &&
                  now.isAfter(start) &&
                  now.isBefore(end) &&
                  status != 'inactive';

              if (isActive) {
                activeMenus.add(doc);
              } else {
                inactiveMenus.add(doc);
              }
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Expanded(
                    child: TabBarView(
                      children: [
                        buildMenuList(activeMenus, true, context),
                        buildMenuList(inactiveMenus, false, context, now),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildMenuList(List<QueryDocumentSnapshot> menus, bool isActiveTab, BuildContext context, [DateTime? now]) {
    if (menus.isEmpty) {
      return const Center(child: Text("No menus available."));
    }

    final effectiveNow = now ?? DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(effectiveNow);

    // Get dinner end time dynamically
    final dinnerRange = getMealTimings()['Dinner']!;
    final dinnerEnd = dinnerRange.end;

    // Compare only time (not date)
    bool isAfterDinnerEndTime(TimeOfDay nowTime, TimeOfDay endTime) {
      return nowTime.hour > endTime.hour ||
          (nowTime.hour == endTime.hour && nowTime.minute > endTime.minute);
    }

    final afterLastMealTime = isAfterDinnerEndTime(currentTime, dinnerEnd);

    return ListView.builder(
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final doc = menus[index];
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;
        final name = data['name'] ?? 'Unnamed';
        final description = data['description'] ?? '';
        final price = data['price'] ?? 'N/A';
        final imageUrl = data['imageUrl'] ?? '';
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final endTime = (data['endTime'] as Timestamp?)?.toDate();
        final remainingOrders = data['availableOrders']?.toString() ?? 'N/A';

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.fastfood, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("Price: ₹$price"),
                              Text("Remaining Bookings: $remainingOrders"),
                              Text("Description: $description"),
                              if (startTime != null && endTime != null)
                                Text("Time: ${formatTime(startTime)} - ${formatTime(endTime)}"),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => EditMenuDialog(docId: docId, data: data),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: isActiveTab
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Confirm Deactivation"),
                                    content: const Text("Are you sure you want to deactivate this item?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("Confirm"),
                                      ),
                                    ],
                                  ),
                                );

                                // ✅ Only proceed if the widget is still mounted AND confirm is true
                                if (context.mounted && confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('extra_menu')
                                      .doc(docId)
                                      .update({'status': 'inactive'});
                                }
                              },

                              child: const Text("Deactivate", style: TextStyle(color: Colors.orange)),
                            )
                          : !afterLastMealTime
                              ? OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.green),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => ActivateDialog(docId: docId, data: data),
                                    );
                                  },
                                  child: const Text("Activate", style: TextStyle(color: Colors.green)),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ActivateDialog and EditMenuDialog definitions remain unchanged
class EditMenuDialog extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditMenuDialog({super.key, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    final descriptionController = TextEditingController(text: data['description'] ?? '');
    final orderController = TextEditingController(text: data['availableOrders']?.toString() ?? '');

    return AlertDialog(
      title: const Text("Edit Menu Item"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: null,
            ),
            TextField(
              controller: orderController,
              decoration: const InputDecoration(labelText: 'Available Orders'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text("Save"),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('extra_menu').doc(docId).update({
              'name': nameController.text.trim(),
              'price': double.tryParse(priceController.text.trim()) ?? 0,
              'description': descriptionController.text.trim(),
              'availableOrders': int.tryParse(orderController.text.trim()) ?? 0,
            });
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}


class ActivateDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const ActivateDialog({super.key, required this.docId, required this.data});

  @override
  State<ActivateDialog> createState() => _ActivateDialogState();
}

class _ActivateDialogState extends State<ActivateDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedMealType;
  final ordersController = TextEditingController();

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = (widget.data['startTime'] as Timestamp).toDate();
    final endTime = (widget.data['endTime'] as Timestamp).toDate();

    final currentTime = TimeOfDay.fromDateTime(now);
    final mealTimings = getMealTimings();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Activate Menu Item", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.data['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(widget.data['description'] ?? '', style: const TextStyle(fontSize: 14)),
              const Divider(height: 24),

              const Text("Select Meal Type:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: mealTimings.entries.where((entry) {
                  final range = entry.value;
                  final afterNow = currentTime.hour < range.end.hour ||
                      (currentTime.hour == range.end.hour && currentTime.minute <= range.end.minute);
                  return afterNow;
                }).map((entry) {
                  return ChoiceChip(
                    label: Text(entry.key),
                    selected: selectedMealType == entry.key,
                    onSelected: (_) => setState(() => selectedMealType = entry.key),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              TextFormField(
                controller: ordersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Available Orders',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter available orders';
                  if (int.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
              ),

              const SizedBox(height: 16),
              Text(
                "Scheduled Time: ${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.lightGreen,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Activate"),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (selectedMealType == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a meal type")),
                );
                return;
              }

              final selectedRange = getMealTimeRange(selectedMealType!);
              final updatedStart = DateTime(now.year, now.month, now.day, selectedRange.start.hour, selectedRange.start.minute);
              final updatedEnd = DateTime(now.year, now.month, now.day, selectedRange.end.hour, selectedRange.end.minute);

              final currentTimeInMinutes = currentTime.hour * 60 + currentTime.minute;
              final endMinutes = selectedRange.end.hour * 60 + selectedRange.end.minute;

              if (currentTimeInMinutes > endMinutes) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid meal type: Time already passed")),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('extra_menu')
                  .doc(widget.docId)
                  .update({
                'status': 'active',
                'availableOrders': int.tryParse(ordersController.text) ?? 0,
                'mealType': selectedMealType,
                'startTime': Timestamp.fromDate(updatedStart),
                'endTime': Timestamp.fromDate(updatedEnd),
              });

              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}